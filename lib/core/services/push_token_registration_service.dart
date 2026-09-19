import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../network/network_config.dart';
import '../push_tokens/data/push_token_remote_ds.dart';
import '../utils/device_info_helper.dart';
import '../utils/global_error_handler.dart';

/// Shared authenticated push-token lifecycle for auth and FCM.
///
/// Pure orchestration layer: FCM token retrieval, retry policy and
/// telemetry swallowing. All database mutations go through the guarded
/// RPCs via [PushTokenRemoteDs] (core data pattern — no direct Supabase
/// calls from application services).
class PushTokenRegistrationService {
  const PushTokenRegistrationService._();

  static const PushTokenRemoteDs _remoteDs = PushTokenRemoteDs();

  static Future<void> requestPermissionAndRegister() async {
    try {
      // Skip the native prompt when the OS-level notification permission is
      // already granted: the primary caller (settings_section) has usually
      // just obtained it through permission_handler, and firing FCM's
      // requestPermission() on top of that is a second native request that
      // can collide with other pending permission dialogs (Sentry
      // EDUZONE-W). Both plugins surface the same underlying OS permission,
      // so a permission_handler "granted" is authoritative for FCM too.
      final notificationStatus = await Permission.notification.status;
      if (!notificationStatus.isGranted) {
        await FirebaseMessaging.instance.requestPermission();
      }
      await registerCurrentUserToken();
    } catch (error, stackTrace) {
      debugPrint('Push permission request failed: ${error.runtimeType}');
      GlobalErrorHandler.logError(error, stackTrace);
    }
  }

  static Future<void> registerCurrentUserToken() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final token = await FirebaseMessaging.instance
            .getToken()
            .timeout(NetworkConfig.telemetryTimeout);
        if (token == null || !_remoteDs.hasAuthenticatedSession) {
          return;
        }
        final packageInfo = await PackageInfo.fromPlatform();
        await _remoteDs.registerPushToken(
          token: token,
          deviceId: DeviceInfoHelper.fingerprint,
          platform: DeviceInfoHelper.platform,
          deviceInfo: DeviceInfoHelper.deviceInfoJson,
          appVersion: packageInfo.version,
        );
        return;
      } catch (error, stackTrace) {
        if (attempt == 2) {
          debugPrint('Push token registration failed: ${error.runtimeType}');
          GlobalErrorHandler.logError(error, stackTrace);
          return;
        }
        await Future<void>.delayed(
          Duration(milliseconds: 250 * (1 << attempt)),
        );
      }
    }
  }

  static Future<void> deactivateCurrentUserToken() async {
    if (!_remoteDs.hasAuthenticatedSession) return;
    try {
      final token = await FirebaseMessaging.instance
          .getToken()
          .timeout(NetworkConfig.telemetryTimeout);
      await _remoteDs.deactivatePushToken(
        token: token,
        deviceId: DeviceInfoHelper.fingerprint,
      );
    } catch (error, stackTrace) {
      debugPrint('Push token deactivation failed: ${error.runtimeType}');
      GlobalErrorHandler.logError(error, stackTrace);
      rethrow;
    }
  }
}
