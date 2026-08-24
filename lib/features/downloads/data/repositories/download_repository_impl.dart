import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/encryption_service.dart';
import '../../domain/entities/download_enums.dart';
import '../../domain/entities/download_progress.dart';
import '../../domain/entities/downloaded_lesson.dart';
import '../../domain/repositories/download_repository.dart';
import '../datasources/download_local_ds.dart';
import '../datasources/download_remote_ds.dart';
import '../services/download_manager.dart';
import '../services/download_manifest_service.dart';
import '../services/download_notification_helper.dart';
import 'download_execution_service.dart';
import 'download_format_selector.dart';
import 'download_link_refresher.dart';
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
  final DownloadFormatSelector _formatSelector;
  final DownloadLinkRefresher _linkRefresher;
  final DownloadManifestService? _manifestService;

  // Assigned in the constructor body (not the initializer list) so it can
  // be wired to the exact same _progressControllers/_downloadManagerIds/
  // _pausedDownloads/_cancelledDownloads/_changeController instances
  // declared below — see the class-level doc comment on those fields.
  late final DownloadExecutionService _executionService;
  final Uuid _uuid;

  // Stream controllers for progress updates. Owned here (not inside
  // DownloadExecutionService) because pauseDownload/resumeDownload/
  // cancelDownload/watchProgress/dispose all need to read or mutate them
  // directly — they're passed to DownloadExecutionService by reference so
  // both sides observe the same session state. See ARCH-006.
  final Map<String, StreamController<DownloadProgress>> _progressControllers = {};
  final Map<String, String> _downloadManagerIds = {};
  final Set<String> _pausedDownloads = {};
  final Set<String> _cancelledDownloads = {};
  final StreamController<void> _changeController = StreamController<void>.broadcast();

  // SECTION-12 FIX (P6.27/P6.28 — "two workers → same lesson → same file"
  // must never happen): startDownload's "already downloaded?" check
  // (`_localDataSource.getDownloadByLessonId`) is a normal `await`ed DB
  // read followed later by an `insertDownload` write — a classic
  // check-then-act race. Two overlapping calls for the *same* lessonId
  // (the realistic trigger being a user double-tapping a "Download"
  // button before the first tap's network round-trip to
  // `authorize_offline_download` returns) could both pass the "not
  // already downloaded" check before either had inserted its row, each
  // claim a separate server entitlement, and each write a separate
  // encrypted file for the same lesson — wasted storage and a duplicate,
  // confusing "downloaded" tile, not a security bypass (both calls are
  // independently, correctly authorized), but exactly the duplication
  // P6.28 asks to prevent. Recording the lessonId here synchronously,
  // *before* the first `await` in the method below, closes that window:
  // Dart's single-threaded execution model means this synchronous prefix
  // (URL validation + the `Set.add` check) always runs to completion
  // before the event loop can interleave a second call, so the second
  // concurrent call for the same lessonId sees it already present and is
  // rejected outright instead of racing the first past the DB check.
  final Set<String> _lessonIdsBeingStarted = {};

  DownloadRepositoryImpl({
    required DownloadRemoteDataSource remoteDataSource,
    required DownloadLocalDataSource localDataSource,
    required DownloadManager downloadManager,
    required EncryptionService encryptionService,
    DownloadManifestService? manifestService,
    Uuid? uuid,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _downloadManager = downloadManager,
        _encryptionService = encryptionService,
        _queryService = DownloadQueryService(localDataSource),
        _formatSelector = const DownloadFormatSelector(),
        _linkRefresher = DownloadLinkRefresher(
          remoteDataSource: remoteDataSource,
          localDataSource: localDataSource,
        ),
        _manifestService = manifestService,
        _uuid = uuid ?? const Uuid() {
    DownloadNotificationHelper.init();
    _executionService = DownloadExecutionService(
      remoteDataSource: remoteDataSource,
      localDataSource: localDataSource,
      downloadManager: downloadManager,
      encryptionService: encryptionService,
      manifestService: _manifestService,
      // Shared by reference with this repository's own session-state
      // fields — see the field-level doc comment above.
      progressControllers: _progressControllers,
      downloadManagerIds: _downloadManagerIds,
      pausedDownloads: _pausedDownloads,
      cancelledDownloads: _cancelledDownloads,
      changeController: _changeController,
    );
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
    // Synchronous check-and-add — see `_lessonIdsBeingStarted`'s doc
    // comment above for why this must stay before the method's first
    // `await` to actually close the race it's meant to close.
    if (!_lessonIdsBeingStarted.add(lessonId)) {
      return const Left(AlreadyDownloadedFailure());
    }
    try {
      // Validate URL
      final uri = Uri.tryParse(videoUrl);
      if (uri == null ||
          !uri.isAbsolute ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        return const Left(UnknownFailure('Invalid video URL')); // check-ignore
      }

      // The download identifier is created before authorization so the
      // server entitlement and the local record share one immutable binding.
      final generatedDownloadId = _localDataSource.generateDownloadId();
      final downloadId = generatedDownloadId.isEmpty ? _uuid.v4() : generatedDownloadId;

      // Check if already downloaded
      final existing = await _localDataSource.getDownloadByLessonId(lessonId);
      if (existing != null) {
        return const Left(AlreadyDownloadedFailure());
      }

      // Ordinary online access is not an offline entitlement. The server
      // validates authentication, enrollment, published content and the
      // already-registered device binding before any content bytes are read.
      final offlineEntitlement = await _remoteDataSource.authorizeOfflineDownload(
        lessonId: lessonId,
        courseId: courseId,
        downloadId: downloadId,
      );

      // Fetch video metadata and format URLs. lessonId is passed so the
      // Edge Function authorizes this specific lesson rather than trusting
      // videoUrl alone -- see the comment on getVideoInfo/video-info.
      if (kDebugMode) debugPrint('🔍 getVideoInfo → calling with url: $videoUrl');
      final videoInfo =
          await _remoteDataSource.getVideoInfo(videoUrl, lessonId: lessonId);
      if (kDebugMode) {
        debugPrint('🔍 getVideoInfo → formats count: ${videoInfo.formats.length}');
        for (final f in videoInfo.formats) {
          debugPrint(
            '  format: quality=${f.quality}, requiresMerge=${f.requiresMerge}, '
            'url=${f.videoUrl.substring(0, f.videoUrl.length.clamp(0, 80))}...',
          );
        }
      }
      final selected = _formatSelector.select(videoInfo, quality);
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
        return const Left(StorageFailure('Insufficient storage space')); // check-ignore
      }

      // Generate paths only after server authorization has succeeded.
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

      final serverExpiresAt = DateTime.tryParse(
        offlineEntitlement['expires_at']?.toString() ?? '',
      );
      if (serverExpiresAt == null) {
        return const Left(UnknownFailure('Offline authorization returned no expiry')); // check-ignore
      }
      final expiresAt = serverExpiresAt;

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
      await _localDataSource.updateDownload(downloadId, {
        'entitlement_id': offlineEntitlement['entitlement_id']?.toString(),
        'server_status': offlineEntitlement['status']?.toString(),
        'server_issued_at': DateTime.tryParse(
          offlineEntitlement['issued_at']?.toString() ?? '',
        )?.millisecondsSinceEpoch,
        'server_expires_at': serverExpiresAt.millisecondsSinceEpoch,
        'server_revoked_at': null,
        'content_version': offlineEntitlement['content_version']?.toString(),
      });
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
        _executionService.execute(
          downloadId: downloadId,
          title: title,
          videoUrl: selected.videoFormat.videoUrl,
          videoSavePath: encryptedPath,
          audioUrl: selected.audioTrack?.url,
          audioSavePath: audioPath,
          encryptionKey: encryptionKey,
          lessonId: lessonId,
          courseId: courseId,
          contentVersion:
              offlineEntitlement['content_version']?.toString() ?? '',
          entitlementId:
              offlineEntitlement['entitlement_id']?.toString() ?? '',
          manifestExpiresAt: expiresAt,
          quality: quality,
          accessExpiresAt: serverExpiresAt,
          sourceUrl: videoUrl,
        ).catchError((Object e, StackTrace stack) {
          if (kDebugMode) debugPrint('❌ startDownload background error: $e\n$stack');
        }),
      );

      return Right(download);
    } catch (e) {
      // `getVideoInfo`/`authorizeOfflineDownload` can now throw
      // NoInternetException/RequestTimeoutException directly (see
      // download_remote_ds.dart's NetworkExceptionMapper wiring), not
      // only ServerException. The previous `on ServerException catch`
      // special-case meant those fell through to the generic
      // `UnknownFailure(e.toString())` branch below, losing the
      // connectivity classification one layer above where it was just
      // established -- the same class of gap fixed for
      // courses/home/notifications/todo/video_player. `failureFromError`
      // preserves it consistently with those.
      return Left(failureFromError(e));
    } finally {
      // Release as soon as the synchronous "claim this lessonId" purpose
      // is served — once `insertDownload` above has actually run (success
      // path) or any early-return/exception path is taken, the guard has
      // done its job: either a real DB row now exists (so the ordinary
      // `getDownloadByLessonId` check catches a further duplicate call the
      // normal way), or nothing was ever claimed and a retry should be
      // allowed immediately rather than staying blocked forever.
      _lessonIdsBeingStarted.remove(lessonId);
    }
  }

  @override
  Future<Either<Failure, void>> pauseDownload(String downloadId) async {
    try {
      // Source-of-truth guard: `StorageService.updateDownloadStatus` already
      // refuses to write a status regression once a row is `'completed'`,
      // but it does so silently (fire-and-forget from here) -- this method
      // would still return `Right(null)` to the caller even though nothing
      // changed, and it would still tear down the manager task / cancel the
      // notification / emit a change event for a download that is actually
      // fine. Checking the persisted status first, before touching anything
      // else, means a stale UI event (button built against a status that
      // flipped to `completed` a moment later) surfaces as an explicit
      // [InvalidDownloadStateFailure] instead of a false-success no-op. Only
      // `downloading -> paused` is a legal transition here; `paused ->
      // paused` is treated as an idempotent success rather than an error,
      // since a duplicate tap on an already-paused row is not a bug.
      final downloadData = await _localDataSource.getDownloadById(downloadId);
      if (downloadData == null) {
        return const Left(NotFoundFailure('Download not found')); // check-ignore
      }
      final currentStatus = downloadData['download_status'] as String?;
      if (currentStatus == 'paused') {
        return const Right(null);
      }
      if (currentStatus != 'downloading') {
        return Left(InvalidDownloadStateFailure( // check-ignore
          'Cannot pause a download in status "$currentStatus"',
        ));
      }

      final managerDownloadId = _downloadManagerIds[downloadId] ?? downloadId;
      _pausedDownloads.add(downloadId);
      await _downloadManager.pauseDownload(managerDownloadId);
      await _localDataSource.updateDownloadStatus(downloadId, 'paused');
      await _manifestService?.markPaused(downloadId);
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
        return const Left(NotFoundFailure('Download not found')); // check-ignore
      }

      // Source-of-truth guard: without this, a call racing with
      // `DownloadExecutionService.execute()` finishing (or a duplicated
      // resume tap on a `downloading`/`completed` row) fell through to the
      // link-refresh + `_executionService.execute(...)` call below
      // unconditionally -- re-running the download pipeline over a file
      // that was already complete, or starting a second concurrent
      // execution for a download that is already running. The SQLite-level
      // guard in `StorageService.updateDownloadStatus` stops the *status
      // column* from regressing off `'completed'`, but does not stop this
      // method from still kicking off a real download run against that
      // same `encryptedPath`/`audioPath`. Only `paused -> downloading` and
      // `failed -> downloading` (retry) are legal entries into resume.
      final currentStatus = downloadData['download_status'] as String?;
      if (currentStatus != 'paused' && currentStatus != 'failed') {
        return Left(InvalidDownloadStateFailure( // check-ignore
          'Cannot resume a download in status "$currentStatus"',
        ));
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
        return const Left(UnknownFailure('Download metadata is incomplete')); // check-ignore
      }

      final quality = qualityLabel != null
          ? VideoQuality.fromLabel(qualityLabel)
          : VideoQuality.p720;
      final accessExpiresAt = downloadData['expires_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (downloadData['expires_at'] as num).toInt(),
            )
          : null;

      final entitlementId = downloadData['entitlement_id']?.toString();
      final localServerStatus = downloadData['server_status']?.toString();
      if (entitlementId == null || entitlementId.isEmpty || localServerStatus != 'ACTIVE') {
        return const Left(UnknownFailure('Offline entitlement is no longer valid')); // check-ignore
      }

      try {
        final server = await _remoteDataSource.revalidateOfflineEntitlement(
          entitlementId: entitlementId,
        );
        final serverStatus = server['status']?.toString();
        final serverExpiresAt = DateTime.tryParse(server['expires_at']?.toString() ?? '');
        await _localDataSource.updateDownload(downloadId, {
          'server_status': serverStatus,
          'server_expires_at': serverExpiresAt?.millisecondsSinceEpoch,
          'server_revoked_at': DateTime.tryParse(server['revoked_at']?.toString() ?? '')
              ?.millisecondsSinceEpoch,
        });
        if (serverStatus != 'ACTIVE' || serverExpiresAt == null ||
            DateTime.now().isAfter(serverExpiresAt)) {
          return const Left(UnknownFailure('Offline entitlement is no longer valid')); // check-ignore
        }
      } on ServerException catch (e) {
        // A transient connectivity failure does not invalidate an otherwise
        // active, unexpired entitlement. Server-side deny responses are not
        // treated as transient by the RPC and remain a hard failure.
        if (e.code != 'network_error') {
          return Left(ServerFailure(e.message));
        }
      }

      // ── Link-refresh ─────────────────────────────────────────────────────
      // Delegated to DownloadLinkRefresher (see ARCH-006): if the stored
      // link is old enough to plausibly have expired, it fetches and
      // persists a fresh one via the original source URL before we execute
      // the download.
      final sourceUrl = (downloadData['source_url'] as String?)?.trim();
      final rawLinkValidatedAt = downloadData['link_validated_at'];
      final linkValidatedAt = rawLinkValidatedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (rawLinkValidatedAt as num).toInt(),
            )
          : null;

      final refreshResult = await _linkRefresher.refreshIfStale(
        downloadId: downloadId,
        currentVideoUrl: videoUrl,
        currentAudioUrl:
            (audioUrl == null || audioUrl.isEmpty) ? null : audioUrl,
        sourceUrl: sourceUrl,
        linkValidatedAt: linkValidatedAt,
        quality: quality,
        lessonId: lessonId,
      );
      final effectiveVideoUrl = refreshResult.videoUrl;
      final effectiveAudioUrl = refreshResult.audioUrl;
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
      await _manifestService?.markRunning(downloadId);

      unawaited(
        _executionService.execute(
          downloadId: downloadId,
          title: title,
          videoUrl: effectiveVideoUrl,
          videoSavePath: encryptedPath,
          audioUrl: effectiveAudioUrl,
          audioSavePath: audioPath,
          encryptionKey: encryptionKey,
          lessonId: lessonId,
          courseId: downloadData['course_id'] as String? ?? '',
          contentVersion: downloadData['content_version']?.toString() ?? '',
          entitlementId: entitlementId,
          manifestExpiresAt: accessExpiresAt,
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
        debugPrint('⚠️ Error cancelling download in manager: ${e.runtimeType}');
      }

      try {
        await _localDataSource.updateDownloadStatus(downloadId, 'failed');
      } catch (e) {
        debugPrint('⚠️ Error updating download status: ${e.runtimeType}');
      }

      final downloadData = await _localDataSource.getDownloadById(downloadId);
      if (downloadData != null) {
        final encryptedPath = downloadData['encrypted_path'] as String?;
        final audioPath = downloadData['audio_path'] as String?;
        await _cleanupDownloadFiles(encryptedPath, audioPath);
      }

      try {
        await _encryptionService.deleteKey(downloadId);
      } catch (e) {
        debugPrint('⚠️ Error deleting key: ${e.runtimeType}');
      }

      await _localDataSource.deleteDownload(downloadId);
      await _manifestService?.deleteForDownload(downloadId);
      _changeController.add(null);
      
      try {
        await _executionService.closeProgressController(downloadId);
      } catch (e) {
        debugPrint('⚠️ Error closing progress controller: ${e.runtimeType}');
      }

      try {
        await DownloadNotificationHelper.cancel(downloadId: downloadId);
      } catch (e) {
        debugPrint('⚠️ Error cancelling notification: ${e.runtimeType}');
      }

      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Future<void> _cleanupDownloadFiles(
    String? encryptedPath,
    String? audioPath,
  ) async {
    if (encryptedPath != null && encryptedPath.isNotEmpty) {
      try {
        await _localDataSource.deleteEncryptedFile(encryptedPath);
      } catch (e) {
        debugPrint('⚠️ Error deleting encrypted file: ${e.runtimeType}');
      }

      try {
        await _localDataSource.deleteEncryptedFile('$encryptedPath.tmp');
      } catch (e) {
        debugPrint('⚠️ Error deleting temp file: ${e.runtimeType}');
      }

      // The chunked-container sidecar index (see ChunkIndex/loadOrBuildIndex
      // in encryption_service.dart) is written next to the encrypted file
      // as `<path>.idx`. It was previously never cleaned up here, leaving
      // an orphaned sidecar file behind on every delete (P6.29/P6.30).
      try {
        await _localDataSource.deleteEncryptedFile('$encryptedPath.idx');
      } catch (e) {
        debugPrint('⚠️ Error deleting index sidecar: ${e.runtimeType}');
      }
    }

    if (audioPath != null && audioPath.isNotEmpty) {
      try {
        await _localDataSource.deleteEncryptedFile(audioPath);
      } catch (e) {
        debugPrint('⚠️ Error deleting audio file: ${e.runtimeType}');
      }

      try {
        await _localDataSource.deleteEncryptedFile('$audioPath.tmp');
      } catch (e) {
        debugPrint('⚠️ Error deleting audio temp file: ${e.runtimeType}');
      }

      try {
        await _localDataSource.deleteEncryptedFile('$audioPath.idx');
      } catch (e) {
        debugPrint('⚠️ Error deleting audio index sidecar: ${e.runtimeType}');
      }
    }
  }

  @override
  Future<Either<Failure, void>> deleteDownload(String downloadId) async {
    try {
      final downloadData = await _localDataSource.getDownloadById(downloadId);

      if (downloadData == null) {
        return const Left(NotFoundFailure('Download not found')); // check-ignore
      }

      final encryptedPath = downloadData['encrypted_path'] as String?;
      final audioPath = downloadData['audio_path'] as String?;
      await _cleanupDownloadFiles(encryptedPath, audioPath);

      try {
        await _encryptionService.deleteKey(downloadId);
      } catch (e) {
        debugPrint('⚠️ Error deleting encryption key: ${e.runtimeType}');
      }

      await _localDataSource.deleteDownload(downloadId);
      await _manifestService?.deleteForDownload(downloadId);
      _changeController.add(null);

      try {
        await _executionService.closeProgressController(downloadId);
      } catch (e) {
        debugPrint('⚠️ Error closing progress controller: ${e.runtimeType}');
      }

      try {
        await DownloadNotificationHelper.cancel(downloadId: downloadId);
      } catch (e) {
        debugPrint('⚠️ Error cancelling notification: ${e.runtimeType}');
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

