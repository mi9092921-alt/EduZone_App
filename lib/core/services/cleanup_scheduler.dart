import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:workmanager/workmanager.dart';

// Architecture exception (reviewed): CleanupScheduler.callbackDispatcher runs
// in WorkManager's own isolate, which has no Flutter binding and no Riverpod
// container (see class doc-comment below), so it cannot reach
// DownloadLocalDataSource through the normal application/domain layer the
// way every other core/ file must. Importing it directly from core/ is the
// smallest safe option today; the correct long-term fix is to extract a
// small feature-agnostic "expired downloads" data contract into core/ or
// shared/ so this isolate entrypoint no longer reaches into
// features/downloads/data/ at all. Tracked as a known architecture debt
// item rather than silently allowed.
import '../../features/downloads/data/datasources/download_local_ds.dart'; // check-ignore
import '../services/encryption_service.dart';
import '../services/storage_service.dart';

/// Service for scheduling automatic cleanup of expired downloads.
///
/// Uses WorkManager on Android to run cleanup tasks periodically.
/// Cleanup runs daily to remove expired downloads and free storage.
///
/// The [callbackDispatcher] runs in its own isolate (no Flutter binding,
/// no Riverpod container). It therefore bootstraps only the lowest-level
/// data-access objects directly, without going through any provider or
/// use-case layer.
class CleanupScheduler {
  static const _cleanupTask = 'cleanupExpiredDownloads';

  /// Initializes the cleanup scheduler.
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
    );
  }

  /// Registers the periodic cleanup task.
  ///
  /// Runs once every 24 hours when the device is connected and battery is
  /// not critically low.
  static Future<void> scheduleCleanup() async {
    await Workmanager().registerPeriodicTask(
      _cleanupTask,
      _cleanupTask,
      frequency: const Duration(hours: 24),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
        requiresCharging: false,
      ),
    );
  }

  /// Callback dispatcher for WorkManager.
  ///
  /// Called by the system when the scheduled task fires.  Bootstraps its
  /// own DB + encryption instances (no Riverpod in this isolate) and
  /// physically deletes every expired download row along with its files
  /// and encryption key.
  @pragma('vm:entry-point')
  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      if (task != _cleanupTask) return false;

      try {
        final storageService = StorageService();
        final localDs = DownloadLocalDataSource(storageService);
        const secureStorage = FlutterSecureStorage();
        final encryptionService = EncryptionService(secureStorage);

        final expiredRows = await localDs.getExpiredDownloads();
        var keyDeletionFailures = 0;

        for (final row in expiredRows) {
          final id = row['id'] as String?;
          if (id == null || id.isEmpty) continue;

          final encryptedPath = row['encrypted_path'] as String?;
          final audioPath = row['audio_path'] as String?;

          // Delete every file variant (the final encrypted file, any
          // in-progress .tmp counterpart, and the chunked-container .idx
          // sidecar written by loadOrBuildIndex — see encryption_service.dart.
          // The .idx file was previously left behind here on every expiry
          // cleanup (P6.29/P6.30 orphan detection gap).
          for (final path in [
            encryptedPath,
            if (encryptedPath != null && encryptedPath.isNotEmpty) ...[
              '$encryptedPath.tmp',
              '$encryptedPath.idx',
            ],
            audioPath,
            if (audioPath != null && audioPath.isNotEmpty) ...[
              '$audioPath.tmp',
              '$audioPath.idx',
            ],
          ]) {
            if (path == null || path.isEmpty) continue;
            try {
              final file = File(path);
              if (await file.exists()) await file.delete();
            } catch (_) {
              // Non-fatal: file may already be gone.
            }
          }

          // Remove the AES key from secure storage. If this fails, do NOT
          // delete the DB row below — leave the record in place so the
          // next cleanup cycle retries this item instead of silently
          // orphaning the key (a record-less key with no way to find and
          // remove it later). This mirrors the same safety net the
          // "crash mid-loop" comment below already relies on, extended to
          // cover a caught (non-crashing) failure too.
          try {
            await encryptionService.deleteKey(id);
          } catch (_) {
            keyDeletionFailures++;
            continue;
          }

          // Remove the DB row last so that a crash mid-loop leaves the
          // record in place and the next run retries the cleanup.
          await localDs.deleteDownload(id);
        }

        if (kDebugMode) {
          debugPrint(
            '[CleanupScheduler] Removed ${expiredRows.length - keyDeletionFailures} '
            'of ${expiredRows.length} expired download(s)'
            '${keyDeletionFailures > 0 ? ' ($keyDeletionFailures key-deletion failure(s), retried next cycle)' : ''}',
          );
        }
        return true;
      } catch (e, stack) {
        if (kDebugMode) {
          debugPrint('[CleanupScheduler] Cleanup failed: $e\n$stack');
        }
        // Return false so WorkManager can retry the task later.
        return false;
      }
    });
  }

  /// Cancels the scheduled cleanup task.
  static Future<void> cancelCleanup() async {
    await Workmanager().cancelAll();
  }
}
