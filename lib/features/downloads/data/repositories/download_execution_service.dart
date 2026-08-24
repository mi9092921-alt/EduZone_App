import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../core/logging/domain/app_event.dart';
import '../../../../core/logging/infrastructure/event_bus.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/services/encryption_service.dart';
import '../../../../core/utils/device_info_helper.dart';
import '../../domain/entities/download_enums.dart';
import '../../domain/entities/download_progress.dart';
import '../../domain/entities/download_session.dart';
import '../datasources/download_local_ds.dart';
import '../datasources/download_remote_ds.dart';
import '../services/download_manager.dart';
import '../services/download_manifest_service.dart';
import '../services/download_notification_helper.dart';

/// Runs a single download end-to-end in the background: downloads (and
/// encrypts) the video/audio track(s), tracks combined progress, persists
/// status transitions, and reports completion/failure/pause.
///
/// Extracted from `DownloadRepositoryImpl` (see ARCH-006 in the
/// architecture review): `_executeDownload` and its `_downloadTrackEncrypted`
/// helper were by far the largest and most stateful piece of the original
/// 969-line file, but they don't need the whole repository — only a fixed
/// set of collaborators and a handful of *shared* session maps that also
/// have to stay visible to `pauseDownload`/`resumeDownload`/`cancelDownload`/
/// `watchProgress` on the repository. Those maps ([progressControllers],
/// [downloadManagerIds], [pausedDownloads], [cancelledDownloads]) and the
/// [changeController] broadcast stream are therefore owned by
/// `DownloadRepositoryImpl` and injected here by reference (not copied),
/// so both sides keep observing/mutating the exact same session state.
///
/// This service intentionally does not return `Either<Failure, ...>` —
/// like the original private method, it drives a fire-and-forget background
/// task and reports outcomes via the progress stream / local data source,
/// not via a return value.
class DownloadExecutionService {
  final DownloadRemoteDataSource _remoteDataSource;
  final DownloadLocalDataSource _localDataSource;
  final DownloadManager _downloadManager;
  final EncryptionService _encryptionService;
  final DownloadManifestService? _manifestService;
  final EventBus? _eventBus;
  final String? Function() _currentUserId;
  final String? Function() _deviceFingerprint;

  // Shared session state, owned by DownloadRepositoryImpl and passed by
  // reference so this service and the repository observe the same state.
  final Map<String, StreamController<DownloadProgress>> _progressControllers;
  final Map<String, String> _downloadManagerIds;
  final Set<String> _pausedDownloads;
  final Set<String> _cancelledDownloads;
  final StreamController<void> _changeController;

  DownloadExecutionService({
    required DownloadRemoteDataSource remoteDataSource,
    required DownloadLocalDataSource localDataSource,
    required DownloadManager downloadManager,
    required EncryptionService encryptionService,
    DownloadManifestService? manifestService,
    // P8.13/Section 15 telemetry: optional and defaults to null (no-op on
    // emit, matching OfflinePolicyEngine's identical convention below) so
    // every existing construction site, including every existing test,
    // keeps working unchanged. Production wiring passes
    // `ref.watch(eventBusProvider)` — see `downloads_provider.dart`.
    EventBus? eventBus,
    String? Function()? currentUserId,
    String? Function()? deviceFingerprint,
    required Map<String, StreamController<DownloadProgress>>
        progressControllers,
    required Map<String, String> downloadManagerIds,
    required Set<String> pausedDownloads,
    required Set<String> cancelledDownloads,
    required StreamController<void> changeController,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _downloadManager = downloadManager,
        _encryptionService = encryptionService,
        _manifestService = manifestService,
        _eventBus = eventBus,
        _currentUserId = currentUserId ?? _defaultCurrentUserId,
        _deviceFingerprint = deviceFingerprint ?? _defaultDeviceFingerprint,
        _progressControllers = progressControllers,
        _downloadManagerIds = downloadManagerIds,
        _pausedDownloads = pausedDownloads,
        _cancelledDownloads = cancelledDownloads,
        _changeController = changeController;

  static String? _defaultCurrentUserId() {
    try {
      return SupabaseService.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  static String? _defaultDeviceFingerprint() {
    try {
      return DeviceInfoHelper.fingerprint;
    } catch (_) {
      return null;
    }
  }

  /// Coarse, machine-readable classification of a download failure for
  /// [DownloadFailedEvent.reason] — deliberately not the raw exception
  /// text (see that class's doc comment for why). Covers the one
  /// filesystem condition this app can distinguish without a native
  /// free-disk-space plugin (none is present in this codebase — see
  /// `SECURITY.md`/`CHANGELOG.md`, "Storage Management" follow-up): the
  /// underlying write actually hit ENOSPC/"no space left on device",
  /// surfaced by `dart:io` as a [FileSystemException] whose message
  /// mentions it (Linux/Android errno 28, and the equivalent macOS/iOS
  /// message text). This is reactive (after the write already failed),
  /// not the proactive free-space *check* Phase 10 of the download
  /// hardening plan calls for — that remains open, tracked below. Public
  /// (not `_`-prefixed) specifically so it's independently unit-testable
  /// without needing a full `execute()` run, mirroring
  /// `DownloadStatusPresentation`'s identical rationale.
  static String classifyDownloadFailure(Object error) {
    if (error is FileSystemException) {
      final message = '${error.message} ${error.osError?.message ?? ''}'
          .toLowerCase();
      if (message.contains('no space left') ||
          message.contains('enospc') ||
          error.osError?.errorCode == 28) {
        return 'storage_full';
      }
      return 'filesystem';
    }
    if (error is SocketException || error is TimeoutException) {
      return 'network';
    }
    return 'unknown';
  }

  /// Downloads [url] into [encryptedSavePath] through the pipelined
  /// download-and-encrypt-in-one-pass path.
  ///
  /// Plaintext fallback is intentionally not allowed here. If the encrypted
  /// pipeline is unavailable (small file, missing Range support, or an
  /// ineligible platform/lifecycle state), the caller must fail the download
  /// rather than writing the media to disk unencrypted first.
  ///
  /// Returns the manager download id, so callers can still route
  /// pause/resume/cancel through `downloadManagerIds` exactly as before —
  /// this method doesn't change any of that bookkeeping, only how the bytes
  /// get from the network onto disk.
  Future<String> _downloadTrackEncrypted({
    required String downloadId,
    required String url,
    required String encryptedSavePath,
    required String encryptionKey,
    required String lessonId,
    required String? qualityLabel,
    String? trackType,
    String? sourceUrl,
    required String manifestDownloadId,
    required String courseId,
    required String contentVersion,
    required String entitlementId,
    required DateTime? manifestExpiresAt,
    required void Function(int received, int total) onProgress,
  }) async {
    final manifest = _manifestService;
    Future<void> onPlanCreated(int totalBytes, List<PlannedChunk> plan) async {
      if (manifest == null) return;
      final now = DateTime.now();
      final effectiveTrack = trackType ?? 'video';
      final effectiveQuality = qualityLabel ?? 'unknown';
      await manifest.persistPlan(
        session: DownloadSession(
          downloadId: manifestDownloadId,
          lessonId: lessonId,
          courseId: courseId,
          contentVersion: contentVersion,
          quality: effectiveQuality,
          trackType: effectiveTrack,
          totalBytes: totalBytes,
          chunkSize: plan.isEmpty ? 0 : plan.first.plaintextLength,
          totalChunks: plan.length,
          completedBytes: 0,
          status: 'downloading',
          createdAt: now,
          updatedAt: now,
          sourceIdentity:
              '$lessonId:$contentVersion:$effectiveQuality:$effectiveTrack',
          entitlementId: entitlementId,
          expiresAt: manifestExpiresAt,
          encryptionVersion: 1,
          containerVersion: 1,
        ),
        plan: plan,
      );
    }

    Future<void> onChunkCommitted(PlannedChunk chunk) async {
      if (manifest == null) return;
      await manifest.commitChunk(
        downloadId: manifestDownloadId,
        chunk: chunk,
      );
    }

    final verifiedChunkIndexes = manifest == null
        ? null
        : await manifest.getVerifiedChunkIndexes(manifestDownloadId);

    final pipelinedManagerId = manifest == null
        ? await _downloadManager.startEncryptedDownload(
            downloadId: downloadId,
            url: url,
            encryptedSavePath: encryptedSavePath,
            encryptionKeyBase64: encryptionKey,
            onProgress: onProgress,
            sourceUrl: sourceUrl,
            qualityLabel: qualityLabel,
            trackType: trackType ?? 'video',
            lessonId: lessonId,
          )
        : await _downloadManager.startEncryptedDownload(
            downloadId: downloadId,
            url: url,
            encryptedSavePath: encryptedSavePath,
            encryptionKeyBase64: encryptionKey,
            onPlanCreated: onPlanCreated,
            onChunkCommitted: onChunkCommitted,
            completedChunkIndexes: verifiedChunkIndexes,
            onProgress: onProgress,
            sourceUrl: sourceUrl,
            qualityLabel: qualityLabel,
            trackType: trackType ?? 'video',
            lessonId: lessonId,
          );
    if (pipelinedManagerId == null) {
      throw StateError(
        'Encrypted streaming is unavailable for this download',
      );
    }
    return pipelinedManagerId;
  }

  /// Executes a (possibly dual-track) download for [downloadId] and drives
  /// it to completion, failure, or pause, updating the local database,
  /// notifications, and the shared progress/change streams throughout.
  Future<void> execute({
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
    String courseId = '',
    String contentVersion = '',
    String entitlementId = '',
    DateTime? manifestExpiresAt,
  }) async {
    // Update status to downloading
    await _localDataSource.updateDownloadStatus(downloadId, 'downloading');
    _changeController.add(null);

    // Create progress controller
    final controller =
        StreamController<DownloadProgress>.broadcast(sync: true);
    _progressControllers[downloadId] = controller;

    final isDualTrack = audioUrl != null && audioSavePath != null;

    var lastStoredProgress = -1.0;
    var lastProgressUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);
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
          now.difference(lastProgressUpdateAt) >=
              const Duration(milliseconds: 700);
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
        // ── Parallel dual-track download ──────────────────────────────────
        if (kDebugMode) {
          debugPrint('🎬 Dual-track download started for $downloadId');
        }

        final videoFuture = _downloadTrackEncrypted(
          downloadId: '${downloadId}_video',
          url: videoUrl,
          encryptedSavePath: videoSavePath,
          encryptionKey: encryptionKey,
          lessonId: lessonId,
          qualityLabel: quality?.label,
          sourceUrl: sourceUrl,
          manifestDownloadId: '${downloadId}_video',
          courseId: courseId,
          contentVersion: contentVersion,
          entitlementId: entitlementId,
          manifestExpiresAt: manifestExpiresAt,
          onProgress: (received, total) {
            videoReceived = received;
            videoTotal = total > 0 ? total : videoTotal;
            emitCombinedProgress();
          },
        );

        final audioFuture = _downloadTrackEncrypted(
          downloadId: '${downloadId}_audio',
          url: audioUrl,
          encryptedSavePath: audioSavePath,
          encryptionKey: encryptionKey,
          lessonId: lessonId,
          qualityLabel: quality?.label,
          trackType: 'audio',
          sourceUrl: sourceUrl,
          manifestDownloadId: '${downloadId}_audio',
          courseId: courseId,
          contentVersion: contentVersion,
          entitlementId: entitlementId,
          manifestExpiresAt: manifestExpiresAt,
          onProgress: (received, total) {
            audioReceived = received;
            audioTotal = total > 0 ? total : audioTotal;
            emitCombinedProgress();
          },
        );

        final results = await Future.wait([videoFuture, audioFuture]);
        _downloadManagerIds[downloadId] = results.first;

        // Both tracks are already encrypted on disk at this point because the
        // only execution path above writes encrypted chunks directly.
        final videoEncrypted = File(videoSavePath);
        final audioEncrypted = File(audioSavePath);

        // Calculate combined file size
        final videoSize = await videoEncrypted.length();
        final audioSize = await audioEncrypted.length();
        final totalFileSize = videoSize + audioSize;
        final checksum = await _encryptionService.calculateChecksum(videoEncrypted);
        final audioChecksum = await _encryptionService.calculateChecksum(audioEncrypted);

        await _localDataSource.updateDownload(downloadId, {
          'download_status': 'completed',
          'progress': 100.0,
          'file_size': totalFileSize,
          'checksum': checksum,
          'audio_checksum': audioChecksum,
        });
      } else {
        // ── Single-file muxed download ─────────────────────────────────────
        final managerDownloadId = await _downloadTrackEncrypted(
          downloadId: downloadId,
          url: videoUrl,
          encryptedSavePath: videoSavePath,
          encryptionKey: encryptionKey,
          lessonId: lessonId,
          qualityLabel: quality?.label,
          sourceUrl: sourceUrl,
          manifestDownloadId: downloadId,
          courseId: courseId,
          contentVersion: contentVersion,
          entitlementId: entitlementId,
          manifestExpiresAt: manifestExpiresAt,
          onProgress: (received, total) {
            videoReceived = received;
            videoTotal = total;
            emitCombinedProgress();
          },
        );
        _downloadManagerIds[downloadId] = managerDownloadId;

        final encryptedFile = File(videoSavePath);
        final checksum =
            await _encryptionService.calculateChecksum(encryptedFile);
        final fileSize = await encryptedFile.length();

        await _localDataSource.updateDownload(downloadId, {
          'download_status': 'completed',
          'progress': 100.0,
          'file_size': fileSize,
          'checksum': checksum,
        });
      }

      await _manifestService?.markCompleted(downloadId);

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
      final failureReason = classifyDownloadFailure(e);
      // P8.13/Section 15 telemetry: previously this class of failure was
      // reported nowhere but the debugPrint above (dev-only). See
      // DownloadFailedEvent's doc comment for why `reason` is a coarse
      // classification, not `e.toString()`.
      _eventBus?.emit(DownloadFailedEvent(
        timestamp: DateTime.now(),
        userId: _currentUserId(),
        deviceId: _deviceFingerprint(),
        downloadId: downloadId,
        reason: failureReason,
      ));
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
      await closeProgressController(downloadId, controller);
    }
  }

  /// Closes and removes the progress controller (and associated manager-id
  /// bookkeeping) for [downloadId]. Safe to call even if [controller] is
  /// already closed or absent from [progressControllers] — used both
  /// internally by [execute]'s `finally` block and externally by
  /// `DownloadRepositoryImpl.cancelDownload`/`deleteDownload`.
  Future<void> closeProgressController(
    String downloadId, [
    StreamController<DownloadProgress>? controller,
  ]) async {
    final progressController =
        controller ?? _progressControllers.remove(downloadId);
    if (progressController != null && !progressController.isClosed) {
      await progressController.close();
    }
    _progressControllers.remove(downloadId);
    _downloadManagerIds.remove(downloadId);
  }
}
