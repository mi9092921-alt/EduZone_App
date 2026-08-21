import 'dart:async';
import 'dart:ui';
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/supabase_client.dart';
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
      unawaited(
        DownloadRecoveryService(
          localDataSource: DownloadLocalDataSource(
            StorageService(secureStorage: const FlutterSecureStorage()),
          ),
        ).reconcile().catchError((Object e, StackTrace stack) {
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
        }),
      );

      // 7b. Same crash-recovery pass, but for leftover *plaintext* offline
      // playback temp files (see the method's doc comment) rather than
      // half-written encrypted downloads — a separate on-disk location and
      // failure mode, so it gets its own best-effort, non-blocking sweep.
      unawaited(
        OfflineCrashRecovery(
          localDataSource: DownloadLocalDataSource(
            StorageService(secureStorage: const FlutterSecureStorage()),
          ),
        ).reconcileOrphanedPlaintextPlaybackFiles().catchError((
          Object e,
          StackTrace stack,
        ) {
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
        }),
      );

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
