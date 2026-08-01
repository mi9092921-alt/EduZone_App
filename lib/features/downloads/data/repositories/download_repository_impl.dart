import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/encryption_service.dart';
import '../../data/models/video_info.dart';
import '../../domain/entities/download_enums.dart';
import '../../domain/entities/download_progress.dart';
import '../../domain/entities/downloaded_lesson.dart';
import '../../domain/repositories/download_repository.dart';
import '../datasources/download_local_ds.dart';
import '../datasources/download_remote_ds.dart';
import '../services/download_manager.dart';
import '../services/download_notification_helper.dart';
import 'download_query_service.dart';

/// Implementation of the download repository.
///
/// Coordinates between remote and local data sources, download manager,
/// and encryption service to provide a complete download management solution.
class DownloadRepositoryImpl implements DownloadRepository {
  final DownloadRemoteDataSource _remoteDataSource;
  final DownloadLocalDataSource _localDataSource;
  final DownloadManager _downloadManager;
  final EncryptionService _encryptionService;
  final DownloadQueryService _queryService;
  final Uuid _uuid;

  // Stream controllers for progress updates
  final Map<String, StreamController<DownloadProgress>> _progressControllers = {};
  final Map<String, String> _downloadManagerIds = {};
  final Set<String> _pausedDownloads = {};
  final Set<String> _cancelledDownloads = {};
  final StreamController<void> _changeController = StreamController<void>.broadcast();

  DownloadRepositoryImpl({
    required DownloadRemoteDataSource remoteDataSource,
    required DownloadLocalDataSource localDataSource,
    required DownloadManager downloadManager,
    required EncryptionService encryptionService,
    Uuid? uuid,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _downloadManager = downloadManager,
        _encryptionService = encryptionService,
        _queryService = DownloadQueryService(localDataSource),
        _uuid = uuid ?? const Uuid() {
    DownloadNotificationHelper.init();
  }

  @override
  Stream<void> get changeStream => _changeController.stream;

  @override
  Future<Either<Failure, DownloadedLesson>> startDownload({
    required String lessonId,
    required String courseId,
    required String courseTitle,
    required String title,
    required String videoUrl,
    required VideoQuality quality,
  }) async {
    try {
      // Validate URL
      final uri = Uri.tryParse(videoUrl);
      if (uri == null ||
          !uri.isAbsolute ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        return const Left(UnknownFailure('Invalid video URL'));
      }

      // Check if already downloaded
      final existing = await _localDataSource.getDownloadByLessonId(lessonId);
      if (existing != null) {
        return const Left(AlreadyDownloadedFailure());
      }

      // Validate course/lesson access through Supabase Edge Function
      final accessResult = await _remoteDataSource.validateCourseAccess(
        lessonId: lessonId,
        courseId: courseId,
      );
      if (!accessResult.allowed) {
        return const Left(
          UnknownFailure('Offline access is not available for this lesson'),
        );
      }

      // Fetch video metadata and format URLs
      if (kDebugMode) debugPrint('🔍 getVideoInfo → calling with url: $videoUrl');
      final videoInfo = await _remoteDataSource.getVideoInfo(videoUrl);
      if (kDebugMode) {
        debugPrint('🔍 getVideoInfo → formats count: ${videoInfo.formats.length}');
        for (final f in videoInfo.formats) {
          debugPrint(
            '  format: quality=${f.quality}, requiresMerge=${f.requiresMerge}, '
            'url=${f.videoUrl.substring(0, f.videoUrl.length.clamp(0, 80))}...',
          );
        }
      }
      final selected = _selectFormats(videoInfo, quality);
      if (kDebugMode) {
        debugPrint(
          '🔍 selectedFormat → quality=${selected.videoFormat.quality}, '
          'isDualTrack=${selected.isDualTrack}',
        );
      }

      // Check storage quota
      final totalStorageUsed = await _localDataSource.getTotalStorageUsed();
      const maxStorageBytes = 2 * 1024 * 1024 * 1024; // 2 GB limit
      final estimatedVideoSize = selected.videoFormat.sizeBytes ?? 0;
      final estimatedAudioSize = selected.audioTrack?.sizeBytes ?? 0;
      final estimatedTotal = estimatedVideoSize + estimatedAudioSize;
      if (estimatedTotal > 0 && totalStorageUsed + estimatedTotal > maxStorageBytes) {
        return const Left(StorageFailure('Insufficient storage space'));
      }

      // Generate download ID and paths
      final generatedDownloadId = _localDataSource.generateDownloadId();
      final downloadId =
          generatedDownloadId.isEmpty ? _uuid.v4() : generatedDownloadId;
      final encryptedPath = await _localDataSource.createFilePath(
        lessonId: lessonId,
        quality: quality.label,
        ext: selected.videoFormat.ext,
      );
      final audioPath = selected.isDualTrack
          ? await _localDataSource.createAudioFilePath(
              lessonId: lessonId,
              quality: quality.label,
              ext: selected.audioTrack!.ext,
            )
          : null;

      // Cap content retention at 30 days or the subscription expiry,
      // whichever is sooner.  The previous fallback (3650 days) would grant
      // 10-year offline access to a lesson whose subscription expired — a
      // commercial and security bug.
      final maxRetention = DateTime.now().add(const Duration(days: 30));
      final subscriptionExpiry = accessResult.expiresAt;
      final expiresAt =
          (subscriptionExpiry == null ||
                  subscriptionExpiry.isAfter(maxRetention))
              ? maxRetention
              : subscriptionExpiry;

      // Generate encryption key (shared for both video and audio files)
      final encryptionKey = _encryptionService.generateEncryptionKey();
      await _encryptionService.storeKey(downloadId, encryptionKey);

      // Create download entity
      final download = DownloadedLesson(
        id: downloadId,
        lessonId: lessonId,
        courseId: courseId,
        courseTitle: courseTitle,
        title: title,
        localPath: encryptedPath,
        encryptedPath: encryptedPath,
        audioPath: audioPath,
        videoUrl: selected.videoFormat.videoUrl,
        audioUrl: selected.audioTrack?.url,
        quality: quality,
        fileSize: 0,
        status: DownloadStatus.pending,
        downloadedAt: DateTime.now(),
        expiresAt: expiresAt,
      );

      // Insert into database and start the download in the background.
      await _localDataSource.insertDownload(download);
      // Persist the original source URL (the parameter passed to startDownload)
      // separately from video_url (which holds the resolved short-lived server
      // link).  source_url is used by resumeDownload() to obtain a fresh link
      // when the existing one has gone stale (TTL < 6h).
      await _localDataSource.updateDownload(downloadId, {
        'source_url': videoUrl,
        'link_validated_at': DateTime.now().millisecondsSinceEpoch,
      });
      _changeController.add(null);
      unawaited(
        _executeDownload(
          downloadId: downloadId,
          title: title,
          videoUrl: selected.videoFormat.videoUrl,
          videoSavePath: encryptedPath,
          audioUrl: selected.audioTrack?.url,
          audioSavePath: audioPath,
          encryptionKey: encryptionKey,
          lessonId: lessonId,
          quality: quality,
          accessExpiresAt: accessResult.expiresAt,
          sourceUrl: videoUrl,
        ).catchError((Object e, StackTrace stack) {
          if (kDebugMode) debugPrint('❌ startDownload background error: $e\n$stack');
        }),
      );

      return Right(download);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  /// Result of format selection: always has a video format, optionally an
  /// audio track for dual-track (requires-merge) downloads.
  _SelectedFormats _selectFormats(VideoInfo videoInfo, VideoQuality quality) {
    // 1. Prefer an exact-quality muxed format (single file, no merge needed)
    final exactMuxed = videoInfo.formats
        .where(
          (f) =>
              f.quality == quality.label && f.hasAudio && !f.requiresMerge,
        )
        .toList();
    if (exactMuxed.isNotEmpty) {
      return _SelectedFormats(exactMuxed.first);
    }

    // 2. Check for an exact-quality video-only format + audio track
    final exactVideo = videoInfo.formats
        .where((f) => f.quality == quality.label && f.requiresMerge)
        .toList();
    if (exactVideo.isNotEmpty) {
      final exactFormat = exactVideo.first;
      final audioTrack = _audioTrackForFormat(exactFormat, videoInfo);
      if (audioTrack != null) {
        return _SelectedFormats(exactFormat, audioTrack: audioTrack);
      }
    }
    if (exactVideo.isNotEmpty) {
      // No audio track from API — treat as best-effort single file
      return _SelectedFormats(exactVideo.first);
    }

    // 3. Fall back: find closest quality among ALL formats
    //    Prefer muxed over merge if qualities are equidistant.
    final allFormats = videoInfo.formats
        .where((f) => f.quality.isNotEmpty)
        .toList();
    if (allFormats.isEmpty) {
      throw Exception('No video formats available for this lesson.');
    }

    allFormats.sort((a, b) {
      final aQ = VideoQuality.fromLabel(a.quality);
      final bQ = VideoQuality.fromLabel(b.quality);
      final aDiff = (aQ.index - quality.index).abs();
      final bDiff = (bQ.index - quality.index).abs();
      if (aDiff != bDiff) return aDiff.compareTo(bDiff);
      // Prefer muxed (lower index = already has audio)
      final aIsMuxed = a.hasAudio && !a.requiresMerge ? 0 : 1;
      final bIsMuxed = b.hasAudio && !b.requiresMerge ? 0 : 1;
      return aIsMuxed.compareTo(bIsMuxed);
    });

    final best = allFormats.first;
    final needsAudio = !best.hasAudio || best.requiresMerge;
    return _SelectedFormats(
      best,
      audioTrack: needsAudio ? _audioTrackForFormat(best, videoInfo) : null,
    );
  }

  AudioTrack? _audioTrackForFormat(VideoFormat format, VideoInfo videoInfo) {
    final formatAudioUrl = format.audioUrl;
    if (formatAudioUrl != null && formatAudioUrl.isNotEmpty) {
      return AudioTrack(
        url: formatAudioUrl,
        sizeBytes: format.audioSizeBytes,
        ext: format.audioExt ?? videoInfo.audio?.ext ?? 'm4a',
      );
    }
    return videoInfo.audio;
  }

  Future<void> _executeDownload({
    required String downloadId,
    required String title,
    required String videoUrl,
    required String videoSavePath,
    String? audioUrl,
    String? audioSavePath,
    required String encryptionKey,
    required String lessonId,
    VideoQuality? quality,
    DateTime? accessExpiresAt,
    String? sourceUrl,
  }) async {
    // Update status to downloading
    await _localDataSource.updateDownloadStatus(downloadId, 'downloading');
    _changeController.add(null);

    // Create progress controller
    final controller = StreamController<DownloadProgress>.broadcast(sync: true);
    _progressControllers[downloadId] = controller;

    final isDualTrack = audioUrl != null && audioSavePath != null;

    final videoTempPath = '$videoSavePath.tmp';
    final audioTempPath = audioSavePath != null ? '$audioSavePath.tmp' : null;

    var lastStoredProgress = -1.0;
    var lastProgressUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);
    var keepTempFiles = false;

    // Shared progress state for parallel downloads
    var videoReceived = 0;
    var videoTotal = 0;
    var audioReceived = 0;
    var audioTotal = 0;

    void emitCombinedProgress() {
      if (_pausedDownloads.contains(downloadId) ||
          _cancelledDownloads.contains(downloadId)) {
        return;
      }

      final totalReceived = videoReceived + audioReceived;
      final totalBytes = videoTotal + audioTotal;
      final progress = DownloadProgressExtension.calculateProgress(
        totalReceived,
        totalBytes,
      );

      final now = DateTime.now();
      final shouldPersist = progress >= 100 ||
          progress - lastStoredProgress >= 1 ||
          now.difference(lastProgressUpdateAt) >= const Duration(milliseconds: 700);
      if (shouldPersist) {
        lastStoredProgress = progress;
        lastProgressUpdateAt = now;
        unawaited(_localDataSource.updateProgress(downloadId, progress));
        DownloadNotificationHelper.showProgress(
          downloadId: downloadId,
          title: title,
          progress: progress,
        );
      }

      controller.add(DownloadProgress(
        downloadId: downloadId,
        lessonId: lessonId,
        receivedBytes: totalReceived,
        totalBytes: totalBytes,
        progress: progress,
        status: DownloadStatus.downloading,
      ));
    }

    try {
      if (isDualTrack) {
        // ── Parallel dual-track download ────────────────────────────────────
        if (kDebugMode) debugPrint('🎬 Dual-track download started for $downloadId');

        final videoFuture = _downloadManager.startDownload(
          downloadId: '${downloadId}_video',
          url: videoUrl,
          savePath: videoTempPath,
          sourceUrl: sourceUrl,
          qualityLabel: quality?.label,
          onProgress: (received, total) {
            videoReceived = received;
            videoTotal = total > 0 ? total : videoTotal;
            emitCombinedProgress();
          },
        );

        final audioFuture = _downloadManager.startDownload(
          downloadId: '${downloadId}_audio',
          url: audioUrl,
          savePath: audioTempPath!,
          sourceUrl: sourceUrl,
          qualityLabel: quality?.label,
          trackType: 'audio',
          onProgress: (received, total) {
            audioReceived = received;
            audioTotal = total > 0 ? total : audioTotal;
            emitCombinedProgress();
          },
        );

        final results = await Future.wait([videoFuture, audioFuture]);
        _downloadManagerIds[downloadId] = results.first;

        // Encrypt both files
        final videoTemp = File(videoTempPath);
        final audioTemp = File(audioTempPath);
        if (!await videoTemp.exists()) throw Exception('Video temp file missing');
        if (!await audioTemp.exists()) throw Exception('Audio temp file missing');

        final videoEncrypted = File(videoSavePath);
        final audioEncrypted = File(audioSavePath);
        await Future.wait([
          _encryptionService.encryptFile(videoTemp, videoEncrypted, encryptionKey),
          _encryptionService.encryptFile(audioTemp, audioEncrypted, encryptionKey),
        ]);

        // Calculate combined file size
        final videoSize = await videoEncrypted.length();
        final audioSize = await audioEncrypted.length();
        final totalFileSize = videoSize + audioSize;
        final checksum = await _encryptionService.calculateChecksum(videoEncrypted);

        await _localDataSource.updateDownload(downloadId, {
          'download_status': 'completed',
          'progress': 100.0,
          'file_size': totalFileSize,
          'checksum': checksum,
        });
      } else {
        // ── Single-file muxed download ───────────────────────────────────────
        final managerDownloadId = await _downloadManager.startDownload(
          downloadId: downloadId,
          url: videoUrl,
          savePath: videoTempPath,
          sourceUrl: sourceUrl,
          qualityLabel: quality?.label,
          onProgress: (received, total) {
            videoReceived = received;
            videoTotal = total;
            emitCombinedProgress();
          },
        );
        _downloadManagerIds[downloadId] = managerDownloadId;

        final tempFile = File(videoTempPath);
        if (!await tempFile.exists()) {
          throw Exception('Download failed: temp file not found');
        }

        final encryptedFile = File(videoSavePath);
        await _encryptionService.encryptFile(tempFile, encryptedFile, encryptionKey);

        final checksum = await _encryptionService.calculateChecksum(encryptedFile);
        final fileSize = await encryptedFile.length();

        await _localDataSource.updateDownload(downloadId, {
          'download_status': 'completed',
          'progress': 100.0,
          'file_size': fileSize,
          'checksum': checksum,
        });
      }

      _changeController.add(null);

      controller.add(DownloadProgress(
        downloadId: downloadId,
        lessonId: lessonId,
        receivedBytes: videoReceived + audioReceived,
        totalBytes: videoTotal + audioTotal,
        progress: 100.0,
        status: DownloadStatus.completed,
      ));

      await DownloadNotificationHelper.showCompleted(
        downloadId: downloadId,
        title: title,
      );

      if (quality != null) {
        try {
          await _remoteDataSource.logDownloadAttempt(
            lessonId: lessonId,
            quality: quality.label,
            accessExpiresAt: accessExpiresAt,
          );
        } catch (_) {
          // Logging failure should not block the finished download.
        }
      }
    } catch (e, stack) {
      if (_pausedDownloads.remove(downloadId)) {
        keepTempFiles = true;
        await _localDataSource.updateDownloadStatus(downloadId, 'paused');
        _changeController.add(null);
        controller.add(DownloadProgress(
          downloadId: downloadId,
          lessonId: lessonId,
          receivedBytes: 0,
          totalBytes: 0,
          progress: lastStoredProgress.clamp(0, 100).toDouble(),
          status: DownloadStatus.paused,
        ));
        return;
      }

      if (_cancelledDownloads.remove(downloadId)) return;

      if (kDebugMode) debugPrint('❌ BACKGROUND DOWNLOAD ERROR: $e\n$stack');
      await _localDataSource.updateDownloadStatus(downloadId, 'failed');
      _changeController.add(null);
      controller.add(DownloadProgress(
        downloadId: downloadId,
        lessonId: lessonId,
        receivedBytes: 0,
        totalBytes: 0,
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
      ));
      await DownloadNotificationHelper.showFailed(
        downloadId: downloadId,
        title: title,
      );
    } finally {
      if (!keepTempFiles) {
        for (final tmpPath in [
          videoTempPath,
          ?audioTempPath,
        ]) {
          try {
            final f = File(tmpPath);
            if (await f.exists()) await f.delete();
          } catch (_) {
            // Best-effort cleanup.
          }
        }
      }
      await _closeProgressController(downloadId, controller);
    }
  }

  Future<void> _closeProgressController(
    String downloadId, [
    StreamController<DownloadProgress>? controller,
  ]) async {
    final progressController = controller ?? _progressControllers.remove(downloadId);
    if (progressController != null) {
      if (!progressController.isClosed) {
        await progressController.close();
      }
    }
    _progressControllers.remove(downloadId);
    _downloadManagerIds.remove(downloadId);
  }

  @override
  Future<Either<Failure, void>> pauseDownload(String downloadId) async {
    try {
      final managerDownloadId = _downloadManagerIds[downloadId] ?? downloadId;
      _pausedDownloads.add(downloadId);
      await _downloadManager.pauseDownload(managerDownloadId);
      await _localDataSource.updateDownloadStatus(downloadId, 'paused');
      _changeController.add(null);
      await DownloadNotificationHelper.cancel(downloadId: downloadId);
      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> resumeDownload(String downloadId) async {
    try {
      final downloadData = await _localDataSource.getDownloadById(downloadId);

      if (downloadData == null) {
        return const Left(NotFoundFailure('Download not found'));
      }

      final title = downloadData['title'] as String? ?? 'Lesson';
      final videoUrl = (downloadData['video_url'] as String?)?.trim();
      final encryptedPath = downloadData['encrypted_path'] as String?;
      final audioPath = downloadData['audio_path'] as String?;
      final audioUrl = (downloadData['audio_url'] as String?)?.trim();
      final lessonId = downloadData['lesson_id'] as String?;
      final qualityLabel = downloadData['quality'] as String?;
      if (videoUrl == null ||
          videoUrl.isEmpty ||
          encryptedPath == null ||
          lessonId == null) {
        return const Left(UnknownFailure('Download metadata is incomplete'));
      }

      final quality = qualityLabel != null
          ? VideoQuality.fromLabel(qualityLabel)
          : VideoQuality.p720;
      final accessExpiresAt = downloadData['expires_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (downloadData['expires_at'] as num).toInt(),
            )
          : null;

      // ── Link-refresh (0.2) ───────────────────────────────────────────────
      // Server links have a TTL of ~6 hours.  If the stored link is older
      // than 5 hours (1h safety margin), attempt to fetch a fresh one via
      // the original source URL before executing the download.
      var effectiveVideoUrl = videoUrl;
      var effectiveAudioUrl =
          (audioUrl == null || audioUrl.isEmpty) ? null : audioUrl;

      final sourceUrl = (downloadData['source_url'] as String?)?.trim();
      final rawLinkValidatedAt = downloadData['link_validated_at'];
      final linkValidatedAt = rawLinkValidatedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (rawLinkValidatedAt as num).toInt(),
            )
          : null;

      final linkStale = linkValidatedAt == null ||
          DateTime.now().difference(linkValidatedAt) >
              const Duration(hours: 5);

      if (linkStale && sourceUrl != null && sourceUrl.isNotEmpty) {
        try {
          final freshInfo = await _remoteDataSource.getVideoInfo(sourceUrl);
          final freshSelected = _selectFormats(freshInfo, quality);
          effectiveVideoUrl = freshSelected.videoFormat.videoUrl;
          effectiveAudioUrl = freshSelected.audioTrack?.url;
          await _localDataSource.updateDownload(downloadId, {
            'video_url': effectiveVideoUrl,
            'audio_url': ?effectiveAudioUrl,
            'link_validated_at': DateTime.now().millisecondsSinceEpoch,
          });
          if (kDebugMode) {
            debugPrint(
              '🔄 resumeDownload: refreshed stale server link for $downloadId',
            );
          }
        } catch (e) {
          // Refresh failed — proceed with the stored (possibly stale) URL.
          // If the link is truly expired the subsequent Dio request will
          // surface a 401/403 instead of failing silently.
          if (kDebugMode) {
            debugPrint(
              '⚠️ resumeDownload: link refresh failed, using stored URL: $e',
            );
          }
        }
      }
      // ────────────────────────────────────────────────────────────────────

      final existingKey = await _encryptionService.retrieveKey(downloadId);
      if (existingKey == null) {
        for (final path in [
          '$encryptedPath.tmp',
          if (audioPath != null) '$audioPath.tmp',
        ]) {
          final tmpFile = File(path);
          if (await tmpFile.exists()) await tmpFile.delete();
        }
      }
      final encryptionKey =
          existingKey ?? _encryptionService.generateEncryptionKey();
      await _encryptionService.storeKey(downloadId, encryptionKey);

      await _localDataSource.updateDownloadStatus(downloadId, 'downloading');
      _changeController.add(null);
      _pausedDownloads.remove(downloadId);
      _cancelledDownloads.remove(downloadId);

      unawaited(
        _executeDownload(
          downloadId: downloadId,
          title: title,
          videoUrl: effectiveVideoUrl,
          videoSavePath: encryptedPath,
          audioUrl: effectiveAudioUrl,
          audioSavePath: audioPath,
          encryptionKey: encryptionKey,
          lessonId: lessonId,
          quality: quality,
          accessExpiresAt: accessExpiresAt,
          sourceUrl: sourceUrl,
        ).catchError((Object e, StackTrace stack) {
          if (kDebugMode) {
            debugPrint('❌ resumeDownload background error: $e\n$stack');
          }
        }),
      );

      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }


  @override
  Future<Either<Failure, void>> cancelDownload(String downloadId) async {
    try {
      final managerDownloadId = _downloadManagerIds[downloadId] ?? downloadId;
      _cancelledDownloads.add(downloadId);
      
      try {
        await _downloadManager.cancelDownload(managerDownloadId);
      } catch (e) {
        debugPrint('⚠️ Error cancelling download in manager: $e');
      }

      try {
        await _localDataSource.updateDownloadStatus(downloadId, 'failed');
      } catch (e) {
        debugPrint('⚠️ Error updating download status: $e');
      }

      final downloadData = await _localDataSource.getDownloadById(downloadId);
      if (downloadData != null) {
        final encryptedPath = downloadData['encrypted_path'] as String?;
        if (encryptedPath != null && encryptedPath.isNotEmpty) {
          try {
            await _localDataSource.deleteEncryptedFile(encryptedPath);
          } catch (e) {
            debugPrint('⚠️ Error deleting encrypted file: $e');
          }
          try {
            await _localDataSource.deleteEncryptedFile('$encryptedPath.tmp');
          } catch (e) {
            debugPrint('⚠️ Error deleting temp file: $e');
          }
        }
      }

      try {
        await _encryptionService.deleteKey(downloadId);
      } catch (e) {
        debugPrint('⚠️ Error deleting key: $e');
      }

      await _localDataSource.deleteDownload(downloadId);
      _changeController.add(null);
      
      try {
        await _closeProgressController(downloadId);
      } catch (e) {
        debugPrint('⚠️ Error closing progress controller: $e');
      }

      try {
        await DownloadNotificationHelper.cancel(downloadId: downloadId);
      } catch (e) {
        debugPrint('⚠️ Error cancelling notification: $e');
      }

      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteDownload(String downloadId) async {
    try {
      final downloadData = await _localDataSource.getDownloadById(downloadId);

      if (downloadData == null) {
        return const Left(NotFoundFailure('Download not found'));
      }

      final encryptedPath = downloadData['encrypted_path'] as String?;
      final audioPath = downloadData['audio_path'] as String?;

      // Delete video file(s)
      if (encryptedPath != null && encryptedPath.isNotEmpty) {
        try {
          await _localDataSource.deleteEncryptedFile(encryptedPath);
        } catch (e) {
          debugPrint('⚠️ Error deleting encrypted file: $e');
        }

        try {
          await _localDataSource.deleteEncryptedFile('$encryptedPath.tmp');
        } catch (e) {
          debugPrint('⚠️ Error deleting temp file: $e');
        }
      }

      // Delete separate audio file(s) for dual-track downloads
      if (audioPath != null && audioPath.isNotEmpty) {
        try {
          await _localDataSource.deleteEncryptedFile(audioPath);
        } catch (e) {
          debugPrint('⚠️ Error deleting audio file: $e');
        }

        try {
          await _localDataSource.deleteEncryptedFile('$audioPath.tmp');
        } catch (e) {
          debugPrint('⚠️ Error deleting audio temp file: $e');
        }
      }

      try {
        await _encryptionService.deleteKey(downloadId);
      } catch (e) {
        debugPrint('⚠️ Error deleting encryption key: $e');
      }

      await _localDataSource.deleteDownload(downloadId);
      _changeController.add(null);

      try {
        await _closeProgressController(downloadId);
      } catch (e) {
        debugPrint('⚠️ Error closing progress controller: $e');
      }

      try {
        await DownloadNotificationHelper.cancel(downloadId: downloadId);
      } catch (e) {
        debugPrint('⚠️ Error cancelling notification: $e');
      }

      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<DownloadedLesson>>> getDownloads() =>
      _queryService.getDownloads();

  @override
  Future<Either<Failure, DownloadedLesson?>> getDownloadByLessonId(
    String lessonId,
  ) =>
      _queryService.getDownloadByLessonId(lessonId);

  @override
  Future<Either<Failure, DownloadedLesson?>> getDownloadById(
    String downloadId,
  ) =>
      _queryService.getDownloadById(downloadId);

  @override
  Future<Either<Failure, List<DownloadedLesson>>> getDownloadsByCourse(
    String courseId,
  ) =>
      _queryService.getDownloadsByCourse(courseId);

  @override
  Future<Either<Failure, List<DownloadedLesson>>> getDownloadsByStatus(
    DownloadStatus status,
  ) =>
      _queryService.getDownloadsByStatus(status);

  @override
  Stream<DownloadProgress> watchProgress(String downloadId) {
    final stream = _progressControllers[downloadId]?.stream;
    return stream?.asBroadcastStream() ?? const Stream.empty();
  }

  @override
  Future<Either<Failure, List<DownloadedLesson>>> getExpiredDownloads() =>
      _queryService.getExpiredDownloads();

  @override
  Future<Either<Failure, int>> cleanupExpiredDownloads() async {
    try {
      final expiredResult = await getExpiredDownloads();
      return await expiredResult.fold<Future<Either<Failure, int>>>(
        (failure) async => Left(failure),
        (expiredDownloads) async {
          var deletedCount = 0;
          for (final download in expiredDownloads) {
            await deleteDownload(download.id);
            deletedCount++;
          }
          return Right(deletedCount);
        },
      );
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> getTotalStorageUsed() =>
      _queryService.getTotalStorageUsed();

  @override
  Future<Either<Failure, void>> updateLastAccessed(String downloadId) =>
      _queryService.updateLastAccessed(downloadId);

  Future<void> dispose() async {
    final controllers = _progressControllers.values.toList(growable: false);
    _progressControllers.clear();
    for (final controller in controllers) {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
    if (!_changeController.isClosed) {
      await _changeController.close();
    }
    _downloadManager.dispose();
  }
}

// ---------------------------------------------------------------------------
// Helper: result of format selection
// ---------------------------------------------------------------------------

/// Holds the video format selected for download and, when the format requires
/// a separate audio stream, the corresponding [AudioTrack].
///
/// When [audioTrack] is null the download is a single muxed file.
/// When [audioTrack] is non-null the download runs two parallel streams.
class _SelectedFormats {
  final VideoFormat videoFormat;
  final AudioTrack? audioTrack;

  const _SelectedFormats(this.videoFormat, {this.audioTrack});

  /// True when a separate audio file must be downloaded alongside the video.
  bool get isDualTrack => audioTrack != null;
}
