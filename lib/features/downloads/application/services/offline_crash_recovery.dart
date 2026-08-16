import 'dart:io';

import '../../data/datasources/download_local_ds.dart';

/// Startup crash-recovery reconciliation for the offline downloads
/// subsystem (P6.31 of
/// `EduZone_Offline_Download_Security_Trusted_Playback_Architecture.md`).
///
/// A download row can only be in `pending` or `downloading` status while
/// something is actively driving it — [DownloadManager]'s in-memory task
/// loop, kicked off by an explicit user action (`startDownload` /
/// `resumeDownload`). Nothing in this codebase auto-resumes a download on
/// app start (see `app_initializer.dart` — `DownloadManager` is never
/// asked to resume anything during boot). So if a row is *already* in one
/// of those two statuses the moment the app cold-starts, the process that
/// was writing to it is gone — most commonly because the app (or device)
/// was killed mid-download — and the row would otherwise sit there
/// forever showing a dead, un-resumable "downloading…" tile.
///
/// This intentionally does **not** touch `paused` downloads — pausing is
/// a deliberate user action and those rows are legitimately resumable
/// through the normal resume flow; reconciling them here would silently
/// discard user intent.
///
/// Called once, fire-and-forget, from [AppInitializer.init] — must never
/// block or fail startup (mirrors `CleanupScheduler`'s
/// try/catch-per-item, best-effort style, since it runs in the exact same
/// "no Riverpod container yet" context).
class OfflineCrashRecovery {
  OfflineCrashRecovery({required DownloadLocalDataSource localDataSource})
      : _localDataSource = localDataSource;

  final DownloadLocalDataSource _localDataSource;

  static const _interruptedStatuses = {'pending', 'downloading'};

  /// Scans every local download (regardless of owning account — a
  /// half-written row is equally orphaned no matter which account started
  /// it, and the currently-signed-in account may not even be resolved yet
  /// this early in startup) and reclassifies any row stuck in
  /// [_interruptedStatuses] to `failed`, so the Downloads screen shows an
  /// actionable "failed, tap to retry" tile instead of a permanently
  /// stuck progress bar. Also best-effort deletes the row's `.tmp`/`.idx`
  /// partial artifacts, consistent with the "a `.tmp` file is never
  /// trusted as valid" rule applied everywhere else in this subsystem
  /// (see `download_repository_impl.dart._cleanupDownloadFiles`).
  ///
  /// Returns the number of rows reconciled.
  Future<int> reconcileInterruptedDownloads() async {
    final rows = await _localDataSource.getDownloads(
      scopeToCurrentUser: false,
    );
    var reconciled = 0;

    for (final row in rows) {
      final status = row['download_status'] as String?;
      if (status == null || !_interruptedStatuses.contains(status)) continue;

      final id = row['id'] as String?;
      if (id == null || id.isEmpty) continue;

      for (final basePath in [
        row['encrypted_path'] as String?,
        row['audio_path'] as String?,
      ]) {
        if (basePath == null || basePath.isEmpty) continue;
        for (final variant in ['$basePath.tmp', '$basePath.idx']) {
          try {
            final file = File(variant);
            if (await file.exists()) await file.delete();
          } catch (_) {
            // Non-fatal — an orphaned partial file left behind here will
            // still be picked up by CleanupScheduler/OfflineAccountGuard
            // path-deletion logic on a later pass.
          }
        }
      }

      try {
        await _localDataSource.updateDownloadStatus(id, 'failed');
        reconciled++;
      } catch (_) {
        // Leave the row as-is for the next app start to retry.
      }
    }

    return reconciled;
  }

  /// Scans and deletes any leftover plaintext playback temp file from
  /// [OfflinePlayerWrapper]'s decrypt-to-temp fallback (dual-track
  /// downloads always use it; single-file downloads fall back to it when
  /// the streaming proxy fails to start — see
  /// `offline_player_wrapper.dart._initializePlayer`).
  ///
  /// Those files are named `<downloadId>_decrypted.<ext>`,
  /// `<downloadId>_video_decrypted.<ext>`, and
  /// `<downloadId>_audio_decrypted.<ext>` in [Directory.systemTemp], and
  /// are normal *unencrypted, playable* video/audio content — the whole
  /// point of the streaming-proxy path (`EdzLocalProxy`) is to avoid ever
  /// writing this kind of file, per P6.13/P6.14 ("No Permanent Plaintext
  /// Cache") of the offline-security architecture doc. The widget cleans
  /// them up itself on normal dispose, but nothing previously handled the
  /// case where the process is killed while one of these files exists on
  /// disk (app/device crash, force-stop, OOM kill mid-playback) — no other
  /// code in this codebase ever looks at [Directory.systemTemp], so a file
  /// left behind that way would otherwise sit there, fully playable by
  /// anything with filesystem access to this app's temp directory,
  /// indefinitely. This closes that gap the same way
  /// [reconcileInterruptedDownloads] closes the equivalent one for
  /// half-written encrypted downloads.
  ///
  /// Best-effort and non-blocking, same reasoning as
  /// [reconcileInterruptedDownloads]: a failure to delete one file must
  /// never stop startup or block deletion of the others, and whatever
  /// isn't cleaned this run is simply retried on the next app start.
  ///
  /// Returns the number of temp files deleted.
  Future<int> reconcileOrphanedPlaintextPlaybackFiles() async {
    final tempDir = Directory.systemTemp;
    var deleted = 0;
    try {
      if (!await tempDir.exists()) return 0;
      await for (final entity in tempDir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.last
            : '';
        final isOrphanedPlaybackTemp = name.contains('_decrypted.') &&
            (name.contains('_video_decrypted.') ||
                name.contains('_audio_decrypted.') ||
                // Single-file fallback path: `<id>_decrypted.<ext>` has
                // neither `_video_` nor `_audio_` before `_decrypted.`.
                RegExp(r'_decrypted\.[^_/\\]+$').hasMatch(name));
        if (!isOrphanedPlaybackTemp) continue;
        try {
          await entity.delete();
          deleted++;
        } catch (_) {
          // Non-fatal — retried on the next app start.
        }
      }
    } catch (_) {
      // Non-fatal — listing the temp directory itself failed; retried on
      // the next app start rather than blocking startup.
    }
    return deleted;
  }
}
