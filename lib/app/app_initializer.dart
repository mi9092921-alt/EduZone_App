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
import '../features/notifications/data/services/fcm_service.dart';

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
            .catchError((Object e) {
          debugPrint('⚠️ CleanupScheduler init failed: $e');
        }),
      );
      unawaited(
        FileDownloader().start().catchError((Object e) {
          debugPrint('⚠️ FileDownloader start failed: $e');
        }),
      );

      // 7. Offline downloads crash recovery (P6.31) — reclassify any
      // download left in `pending`/`downloading` status by a previous
      // process that died mid-download, so it shows as an actionable
      // "failed" tile instead of a permanently stuck progress bar.
      // Constructed directly (not via Riverpod) because no ProviderScope
      // exists yet at this point in startup — same constraint
      // CleanupScheduler's isolate callback already has.
      unawaited(
        OfflineCrashRecovery(
          localDataSource: DownloadLocalDataSource(
            StorageService(secureStorage: const FlutterSecureStorage()),
          ),
        ).reconcileInterruptedDownloads().catchError((Object e) {
          debugPrint('⚠️ Offline crash-recovery reconciliation failed: $e');
          return 0;
        }),
      );

    } catch (e) {
      debugPrint('CRITICAL INITIALIZATION ERROR: $e');
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
