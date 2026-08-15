import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../../core/l10n/arb/app_localizations.dart';

/// Helper to handle native download progress notifications using flutter_local_notifications.
class DownloadNotificationHelper {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static bool get _isTest => Platform.environment.containsKey('FLUTTER_TEST');

  /// Initializes the local notification plugin.
  static Future<void> init() async {
    if (_initialized) return;
    if (_isTest) {
      _initialized = true;
      return;
    }
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

      await _plugin.initialize(
        settings: initSettings,
      );
      _initialized = true;
    } catch (e) {
      debugPrint(
        'DownloadNotificationHelper Init Error: ${e.runtimeType}',
      );
    }
  }

  static AppLocalizations get _l10n =>
      lookupAppLocalizations(PlatformDispatcher.instance.locale);

  /// Updates a progress notification for a download.
  static Future<void> showProgress({
    required String downloadId,
    required String title,
    required double progress,
    String? customTitle,
    String? customBody,
    String? customSubtitle,
  }) async {
    if (_isTest) {
      debugPrint('[TEST] Download Progress: $title - $progress%');
      return;
    }
    await init();
    final id = downloadId.hashCode;
    final l10n = _l10n;

    final androidDetails = AndroidNotificationDetails(
      'download_channel_id',
      'Downloads',
      channelDescription: 'Notifications for download progress',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: progress.round(),
      ongoing: true,
    );

    final iosDetails = DarwinNotificationDetails(
      subtitle: customSubtitle ?? l10n.downloadingSubtitle,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationTitle = customTitle ?? l10n.downloadingTitle(title);
    final notificationBody =
        customBody ?? l10n.downloadingProgress(progress.toStringAsFixed(0));

    await _plugin.show(
      id: id,
      title: notificationTitle,
      body: notificationBody,
      notificationDetails: notificationDetails,
    );
  }

  /// Shows a notification indicating the download has finished successfully.
  static Future<void> showCompleted({
    required String downloadId,
    required String title,
    String? customTitle,
  }) async {
    if (_isTest) {
      debugPrint('[TEST] Download Completed: $title');
      return;
    }
    await init();
    final id = downloadId.hashCode;
    final l10n = _l10n;

    const androidDetails = AndroidNotificationDetails(
      'download_channel_id',
      'Downloads',
      channelDescription: 'Notifications for download progress',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationTitle = customTitle ?? l10n.downloadCompleted;

    await _plugin.show(
      id: id,
      title: notificationTitle,
      body: title,
      notificationDetails: notificationDetails,
    );
  }

  /// Shows a notification indicating the download has failed.
  static Future<void> showFailed({
    required String downloadId,
    required String title,
    String? customTitle,
  }) async {
    if (_isTest) {
      debugPrint('[TEST] Download Failed: $title');
      return;
    }
    await init();
    final id = downloadId.hashCode;
    final l10n = _l10n;

    const androidDetails = AndroidNotificationDetails(
      'download_channel_id',
      'Downloads',
      channelDescription: 'Notifications for download progress',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationTitle = customTitle ?? l10n.downloadFailed;

    await _plugin.show(
      id: id,
      title: notificationTitle,
      body: title,
      notificationDetails: notificationDetails,
    );
  }

  /// Cancels a notification by download ID.
  static Future<void> cancel({required String downloadId}) async {
    if (_isTest) {
      debugPrint('[TEST] Cancel Notification: $downloadId');
      return;
    }
    await init();
    final id = downloadId.hashCode;
    await _plugin.cancel(id: id);
  }
}
