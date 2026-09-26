import 'dart:async';
import 'dart:ui';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../core/network/supabase_client.dart';
import '../core/security/secure_storage_config.dart';
import '../core/security/security_service.dart';
import '../core/services/storage_service.dart';
import '../core/utils/device_info_helper.dart';
import '../core/utils/global_error_handler.dart';
import '../features/downloads/application/services/offline_crash_recovery.dart';
import '../features/downloads/data/datasources/download_local_ds.dart';
import '../features/downloads/data/services/cleanup_scheduler.dart';
import '../features/downloads/data/services/download_manager.dart';
import '../features/downloads/data/services/download_recovery_service.dart';
import '../features/notifications/data/services/fcm_service.dart';

class AppInitializer {
  static late final SharedPreferences prefs;

  static Future<void> init() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();

      // 1. Mandatory Local Prefs with Timeout
      prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException(
          'SharedPreferences timed out',
        ), // check-ignore
      );

      // 2. Platform Config
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
      );

      // 2.5. Register Arabic relative-time messages for the `timeago`
      // package. It only ships English/Spanish by default — every
      // `timeago.format(date, locale: 'ar')` call site (Todo due dates in
      // TodoDateFormatter, notification timestamps in notification_tile,
      // and the course "last watched" label in course_details_screen) was
      // silently falling back to English, e.g. an Arabic overdue label
      // wrapping an English "18 hours ago" instead of a real Arabic
      // relative time. This is a one-line, synchronous, no-I/O call, so it
      // must simply run once before first frame — same reasoning as the
      // Platform Config step right above.
      timeago.setLocaleMessages('ar', timeago.ArMessages());
      timeago.setLocaleMessages('ar_short', timeago.ArShortMessages());

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

      // 4.5. MediaKit is initialized lazily by the player4/offline player
      // immediately before their first native Player is created. The YouTube
      // player does not use libmpv, so loading it before runApp needlessly
      // blocks the first frame and causes large startup frame drops.

      // 5. Initialize Notifications. FCM init also wires the local
      // notification channels (FcmService.init → _setupLocalNotifications),
      // so there is nothing to branch on: no user-facing push opt-out exists
      // (the old 'push_notifications_enabled' pref was never written by any
      // screen, leaving the "local-only" branch unreachable dead code), and
      // permission prompting stays deferred to the permissions surface.
      unawaited(FcmService.init());

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
      //
      // EDUZONE-2 (Sentry, SqfliteDatabaseException: database_closed,
      // reproduced on every launch): these passes previously closed their
      // StorageService in a `finally` block. sqflite's `openDatabase()`
      // defaults to `singleInstance: true`, which means every StorageService
      // opened against the same on-disk path (`eduzone_downloads.db`) —
      // these, the long-lived instance behind `storageServiceProvider`, and
      // `CleanupScheduler`'s main-isolate usage — share ONE underlying
      // native connection. Whichever pass finished first and called
      // `close()` tore down the connection out from under the others,
      // which then threw `database_closed` — deterministically, on every
      // cold start, exactly as reported. There is nothing to leak by not
      // closing here: the connection is a process-lifetime, path-keyed
      // cache owned by sqflite itself; a one-shot wrapper around a shared
      // resource must not unilaterally close it.
      //
      // 7-7e run concurrently (`unawaited`, fired back-to-back, no `await`
      // between them) and each is an independent best-effort sweep with a
      // distinct on-disk target and failure mode — kept as separate calls
      // (via the shared [_runRecoverySweep] wrapper for the identical
      // try/log/Sentry/fallback scaffolding) so one failure can never hide
      // another.
      unawaited(
        _runRecoverySweep<DownloadRecoveryReport>(
          label:
              'Durable download recovery', // check-ignore -- debug-only sweep label, never user-facing
          // Section 15: a reconcile() failure here means potentially
          // corrupted/half-written encrypted downloads are never
          // detected/repaired for this launch — worth Sentry visibility,
          // not just a local console line.
          fallback: const DownloadRecoveryReport(
            sessionsScanned: 0,
            chunksReset: 0,
            chunksInvalidated: 0,
          ),
          sweep: (localDataSource) => DownloadRecoveryService(
            localDataSource: localDataSource,
          ).reconcile(),
        ),
      );

      // 7b. Same crash-recovery pass, but for leftover *plaintext* offline
      // playback temp files (see the method's doc comment) rather than
      // half-written encrypted downloads — a separate on-disk location and
      // failure mode, so it gets its own best-effort, non-blocking sweep.
      // Section 15 + P6.14 (offline security architecture): a failure here
      // means leftover *plaintext* decrypted video may remain on disk
      // indefinitely with nothing scheduled to catch it — this is exactly
      // the kind of failure that must never go unobserved.
      unawaited(
        _runRecoverySweep<int>(
          label:
              'Orphaned plaintext playback file cleanup', // check-ignore -- debug-only
          fallback: 0,
          sweep: (localDataSource) => OfflineCrashRecovery(
            localDataSource: localDataSource,
          ).reconcileOrphanedPlaintextPlaybackFiles(),
        ),
      );

      // 7c. download-subsystem-production-hardening-plan.md, "Manifest +
      // Crash Recovery" — the "DB exists + [process gone]" mandatory case.
      // OfflineCrashRecovery.reconcileInterruptedDownloads() reclassifies
      // any row still stuck in `pending`/`downloading` at cold-start
      // (impossible unless the process that was driving it died —
      // see the method's own doc comment) to `failed`, so the Downloads
      // screen shows an actionable "failed, tap to retry" tile instead of a
      // permanently stuck progress bar. Its own pass (not folded into 7b)
      // for the same reason 7 and 7b are separate: distinct on-disk targets
      // and failure modes deserve independent best-effort sweeps.
      unawaited(
        _runRecoverySweep<int>(
          label:
              'Interrupted download reconciliation', // check-ignore -- debug-only
          fallback: 0,
          sweep: (localDataSource) => OfflineCrashRecovery(
            localDataSource: localDataSource,
          ).reconcileInterruptedDownloads(),
        ),
      );

      // 7d. Same plan, "DB missing + file exists" / orphan video/audio
      // mandatory cases. See
      // OfflineCrashRecovery.reconcileOrphanedDownloadFiles's doc comment
      // for the concrete reachable path that produces these orphans today
      // (DownloadRepositoryImpl._cleanupDownloadFiles can delete a row
      // whose own file deletion silently failed). A failure here means a
      // file whose DB row is already gone (and whose encryption key is
      // already gone) stays on disk, permanently unplayable, indefinitely —
      // silent storage waste with nothing surfaced to diagnose why.
      unawaited(
        _runRecoverySweep<int>(
          label: 'Orphaned download file cleanup', // check-ignore -- debug-only
          fallback: 0,
          sweep: (localDataSource) => OfflineCrashRecovery(
            localDataSource: localDataSource,
          ).reconcileOrphanedDownloadFiles(),
        ),
      );

      // 7e. Same plan, "DB exists + file missing" mandatory case, the one
      // entry 7c/7d don't already cover between them (7c only reclassifies
      // pending/downloading rows; 7d only deletes files no row claims). A
      // `completed` row whose file has actually disappeared (external
      // storage cleanup, manual tampering, an I/O fault) would otherwise
      // sit in the Downloads list looking fully playable until the user
      // taps it and OfflinePolicyEngine denies it at playback time — the
      // correct fail-safe outcome, but with no "tap to retry" affordance
      // in the meantime. See
      // OfflineCrashRecovery.reconcileMissingCompletedFiles's doc comment.
      unawaited(
        _runRecoverySweep<int>(
          label:
              'Missing completed-download file reconciliation', // check-ignore -- debug-only
          fallback: 0,
          sweep: (localDataSource) => OfflineCrashRecovery(
            localDataSource: localDataSource,
          ).reconcileMissingCompletedFiles(),
        ),
      );
    } catch (e) {
      debugPrint('CRITICAL INITIALIZATION ERROR: ${e.runtimeType}');
      // Re-throw to be caught by runZonedGuarded
      rethrow;
    }
  }

  /// Shared scaffolding for the cold-start recovery sweeps (7-7e above):
  /// constructs a fresh StorageService-backed data source, runs [sweep],
  /// and converts any failure into a Sentry report plus a debug console
  /// line before returning [fallback] — a sweep failure must never block
  /// or fail startup, but must also never be invisible (Section 15).
  ///
  /// The data source is deliberately never closed here — see the EDUZONE-2
  /// note on pass 7: it wraps the shared singleInstance sqflite connection.
  static Future<T> _runRecoverySweep<T>({
    required String label,
    required T fallback,
    required Future<T> Function(DownloadLocalDataSource localDataSource) sweep,
  }) async {
    final storageService = StorageService(secureStorage: hardenedSecureStorage);
    try {
      return await sweep(DownloadLocalDataSource(storageService));
    } catch (e, stack) {
      debugPrint('⚠️ $label failed: ${e.runtimeType}');
      GlobalErrorHandler.logError(e, stack);
      return fallback;
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
