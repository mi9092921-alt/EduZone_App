import 'dart:async';
import 'dart:ui';
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/supabase_client.dart';
import '../core/security/secure_storage_config.dart';
import '../core/security/security_service.dart';
import '../core/services/cleanup_scheduler.dart';
import '../core/services/storage_service.dart';
import '../core/utils/device_info_helper.dart';
import '../features/downloads/application/services/offline_crash_recovery.dart';
import '../features/downloads/data/datasources/download_local_ds.dart';
import '../features/downloads/data/services/download_manager.dart';
import '../features/downloads/data/services/download_recovery_service.dart';
import '../features/notifications/data/services/fcm_service.dart';
import '../shared/utils/global_error_handler.dart';

class AppInitializer {
  static late final SharedPreferences prefs;

  static Future<void> init() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();

      // 1. Mandatory Local Prefs with Timeout
      prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('SharedPreferences timed out'), // check-ignore
      );

      // 2. Platform Config
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
      );

      // 3. Security protections (screenshot guard, screen-share guard, freeRASP).
      // Requires SECURITY_ANDROID_SIGNING_HASH / SECURITY_IOS_TEAM_ID to be
      // supplied via --dart-define-from-file=.env.security in release builds
      // (see lib/core/security/freerasp_config.dart). Individual guard
      // failures are caught internally and logged — they never block startup.
      await SecurityService.init();

      // 4. Critical Network Services with Retry.
      // SupabaseService.initialize() and DeviceInfoHelper.init() have no
      // data dependency on each other (device fingerprinting is purely
      // local — device_info_plus + local hashing, no network call), so
      // they run concurrently instead of sequentially. This shortens
      // startup by DeviceInfoHelper.init()'s duration on every launch.
      // Both are still covered by the same retry+timeout policy: if either
      // fails, the whole pair is retried together.
      await _initializeWithRetry(() async {
        await Future.wait([
          SupabaseService.initialize(),
          DeviceInfoHelper.init(),
        ]);
      });

      // 4.5. Initialize Media Kit (libmpv)
      MediaKit.ensureInitialized();

      // 5. Initialize Notifications & Local Channels
      final pushEnabled = prefs.getBool('push_notifications_enabled') ?? true;
      if (pushEnabled) {
        unawaited(FcmService.init());
      } else {
        unawaited(FcmService.initLocalNotifications());
      }

      // 6. Initialize Background Downloader & Cleanup Scheduler
      //
      // handleTokenRefresh is a top-level @pragma('vm:entry-point') function.
      // Its CallbackHandle must be resolved once in the main isolate so that
      // the Dart VM registers it in the plugin callback lookup table.  Without
      // this call, PluginUtilities.getCallbackHandle(handleTokenRefresh) returns
      // null inside DownloadManager, silently disabling the onAuth link-refresh
      // even though all other code is correct.
      PluginUtilities.getCallbackHandle(handleTokenRefresh);

      unawaited(
        CleanupScheduler.initialize()
            .then((_) => CleanupScheduler.scheduleCleanup())
            .catchError((Object e, StackTrace stack) {
          debugPrint('⚠️ CleanupScheduler init failed: ${e.runtimeType}');
          // Section 15 ("background-task failures" is explicitly in the
          // audit list): this used to be debugPrint-only, so a
          // CleanupScheduler init failure in production had zero
          // observability — the offline-download expiry/orphan sweep
          // would simply never run again with no diagnostic record
          // anywhere. Sentry is already configured by this point (see
          // handleTokenRefresh's identical precedent in
          // download_manager.dart) so this is safe to call unconditionally.
          GlobalErrorHandler.logError(e, stack);
        }),
      );
      unawaited(
        FileDownloader().start().catchError((Object e, StackTrace stack) {
          debugPrint('⚠️ FileDownloader start failed: ${e.runtimeType}');
          // Same rationale as CleanupScheduler above: a FileDownloader
          // start failure silently disables all background downloads for
          // the session with no prior observability signal.
          GlobalErrorHandler.logError(e, stack);
        }),
      );

      // 7. Durable download recovery: reconcile the SQLite manifest with
      // encrypted files before any session is resumed. This preserves safe
      // verified chunks instead of downgrading the whole download to failed.
      // Constructed directly (not via Riverpod) because no ProviderScope
      // exists yet at this point in startup — same constraint
      // CleanupScheduler's isolate callback already has.
      unawaited(() async {
        final recoveryStorageService =
            StorageService(secureStorage: hardenedSecureStorage);
        try {
          return await DownloadRecoveryService(
            localDataSource: DownloadLocalDataSource(recoveryStorageService),
          ).reconcile();
        } catch (e, stack) {
          debugPrint(
            '⚠️ Durable download recovery failed: '
            '${e.runtimeType}',
          );
          // Section 15: a reconcile() failure here means potentially
          // corrupted/half-written encrypted downloads are never
          // detected/repaired for this launch — worth Sentry visibility,
          // not just a local console line.
          GlobalErrorHandler.logError(e, stack);
          return const DownloadRecoveryReport(
            sessionsScanned: 0,
            chunksReset: 0,
            chunksInvalidated: 0,
          );
        }
        // EDUZONE-2 (Sentry, SqfliteDatabaseException: database_closed,
        // reproduced on every launch): this pass previously closed
        // `recoveryStorageService` in a `finally` block. sqflite's
        // `openDatabase()` defaults to `singleInstance: true`, which
        // means every `StorageService` opened against the same on-disk
        // path (`eduzone_downloads.db`) — this one, the four sibling
        // one-shot instances in 7b-7e below, the long-lived instance
        // behind `storageServiceProvider`, and `CleanupScheduler`'s
        // main-isolate usage — share ONE underlying native connection,
        // not five/six independent ones. Passes 7-7e all run
        // concurrently (`unawaited`, fired back-to-back, no `await`
        // between them) and each held its own non-null `_database`
        // field pointing at that shared connection. Whichever pass
        // finished first and called `close()` tore down the connection
        // out from under every other pass/provider still mid-flight or
        // about to run its first query, which then threw
        // `database_closed` — deterministically, on every cold start,
        // exactly as reported. There is nothing to leak by not closing
        // here: the connection is a process-lifetime, path-keyed cache
        // owned by sqflite itself, already kept alive for the rest of
        // the app's life by `storageServiceProvider`, and released by
        // the OS at process death — a one-shot wrapper around a shared
        // resource must not unilaterally close it.
      }());

      // 7b. Same crash-recovery pass, but for leftover *plaintext* offline
      // playback temp files (see the method's doc comment) rather than
      // half-written encrypted downloads — a separate on-disk location and
      // failure mode, so it gets its own best-effort, non-blocking sweep.
      unawaited(() async {
        final crashRecoveryStorageService =
            StorageService(secureStorage: hardenedSecureStorage);
        try {
          return await OfflineCrashRecovery(
            localDataSource:
                DownloadLocalDataSource(crashRecoveryStorageService),
          ).reconcileOrphanedPlaintextPlaybackFiles();
        } catch (e, stack) {
          debugPrint(
            '⚠️ Orphaned plaintext playback file cleanup failed: '
            '${e.runtimeType}',
          );
          // Section 15 + P6.14 (offline security architecture): a failure
          // here means leftover *plaintext* decrypted video may remain on
          // disk indefinitely with nothing scheduled to catch it — this is
          // exactly the kind of failure that must never go unobserved.
          GlobalErrorHandler.logError(e, stack);
          return 0;
        }
        // No `finally { crashRecoveryStorageService.close() }` — see the
        // EDUZONE-2 explanation on pass 7 above: this shares the same
        // singleInstance sqflite connection as every other pass here,
        // and closing it out from under them is the actual bug, not a
        // missing cleanup.
      }());

      // 7c. download-subsystem-production-hardening-plan.md, "Manifest +
      // Crash Recovery" — the "DB exists + [process gone]" mandatory case.
      // OfflineCrashRecovery.reconcileInterruptedDownloads() reclassifies
      // any row still stuck in `pending`/`downloading` at cold-start
      // (impossible unless the process that was driving it died —
      // see the method's own doc comment) to `failed`, so the Downloads
      // screen shows an actionable "failed, tap to retry" tile instead of
      // a permanently stuck progress bar. This method already existed,
      // fully implemented and covered by
      // offline_crash_recovery_test.dart, but was never actually called
      // from anywhere in the app — 7b above only reconciles the
      // *plaintext-playback-temp-file* half of OfflineCrashRecovery, never
      // this one. A separate pass (not folded into 7b) for the same
      // reason 7 and 7b are already kept separate: distinct on-disk
      // targets and failure modes deserve independent best-effort sweeps
      // rather than one failure hiding the other.
      unawaited(() async {
        final interruptedDownloadsStorageService =
            StorageService(secureStorage: hardenedSecureStorage);
        try {
          return await OfflineCrashRecovery(
            localDataSource:
                DownloadLocalDataSource(interruptedDownloadsStorageService),
          ).reconcileInterruptedDownloads();
        } catch (e, stack) {
          debugPrint(
            '⚠️ Interrupted download reconciliation failed: '
            '${e.runtimeType}',
          );
          // Same observability rationale as 7/7b: a failure here means
          // downloads killed mid-write stay stuck showing "downloading…"
          // forever with nothing surfaced to diagnose why.
          GlobalErrorHandler.logError(e, stack);
          return 0;
        }
        // No close() here either — see the EDUZONE-2 explanation on
        // pass 7 above.
      }());

      // 7d. download-subsystem-production-hardening-plan.md, "Manifest +
      // Crash Recovery" — the "DB missing + file exists" / orphan
      // video/audio mandatory cases. See
      // OfflineCrashRecovery.reconcileOrphanedDownloadFiles's doc comment
      // for the concrete reachable path that produces these orphans today
      // (DownloadRepositoryImpl._cleanupDownloadFiles can delete a row
      // whose own file deletion silently failed). Deliberately its own
      // pass rather than folded into 7c: 7c only ever changes a row's
      // status/sidecar files, never lists or deletes anything based on
      // the *absence* of a row, which is a distinct failure mode worth
      // its own independent best-effort sweep and its own Sentry signal.
      unawaited(() async {
        final orphanedFilesStorageService =
            StorageService(secureStorage: hardenedSecureStorage);
        try {
          return await OfflineCrashRecovery(
            localDataSource:
                DownloadLocalDataSource(orphanedFilesStorageService),
          ).reconcileOrphanedDownloadFiles();
        } catch (e, stack) {
          debugPrint(
            '⚠️ Orphaned download file cleanup failed: ${e.runtimeType}',
          );
          // A failure here means a file whose DB row is already gone (and
          // whose encryption key is already gone) stays on disk,
          // permanently unplayable, indefinitely — silent storage waste
          // with nothing surfaced to diagnose why.
          GlobalErrorHandler.logError(e, stack);
          return 0;
        }
        // No close() here either — see the EDUZONE-2 explanation on
        // pass 7 above.
      }());

      // 7e. download-subsystem-production-hardening-plan.md, "Manifest +
      // Crash Recovery" — the "DB exists + file missing" mandatory case,
      // the one entry in that list 7c/7d don't already cover between them
      // (7c only reclassifies pending/downloading rows; 7d only deletes
      // files no row claims). A `completed` row whose file has actually
      // disappeared (external storage cleanup, manual tampering, an
      // I/O fault) would otherwise sit in the Downloads list looking
      // fully playable until the user taps it and OfflinePolicyEngine
      // denies it at playback time — the correct fail-safe outcome, but
      // with no "tap to retry" affordance in the meantime. See
      // OfflineCrashRecovery.reconcileMissingCompletedFiles's doc comment.
      unawaited(() async {
        final missingFilesStorageService =
            StorageService(secureStorage: hardenedSecureStorage);
        try {
          return await OfflineCrashRecovery(
            localDataSource:
                DownloadLocalDataSource(missingFilesStorageService),
          ).reconcileMissingCompletedFiles();
        } catch (e, stack) {
          debugPrint(
            '⚠️ Missing completed-download file reconciliation failed: '
            '${e.runtimeType}',
          );
          // A failure here means a "completed" tile can keep silently
          // pointing at a file that no longer exists, with nothing
          // surfaced to diagnose why the next playback attempt fails.
          GlobalErrorHandler.logError(e, stack);
          return 0;
        }
        // No close() here either — see the EDUZONE-2 explanation on
        // pass 7 above.
      }());

    } catch (e) {
      debugPrint('CRITICAL INITIALIZATION ERROR: ${e.runtimeType}');
      // Re-throw to be caught by runZonedGuarded
      rethrow;
    }
  }

  static Future<void> _initializeWithRetry(
    Future<void> Function() action, {
    int maxRetries = 3,
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        await action().timeout(const Duration(seconds: 10));
        return;
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) rethrow;
        await Future.delayed(Duration(seconds: attempts * 2));
      }
    }
  }
}
