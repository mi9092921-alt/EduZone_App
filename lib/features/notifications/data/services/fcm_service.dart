import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/network_config.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/device_info_helper.dart';
import '../../../../shared/utils/global_error_handler.dart';

class FcmService {
  static final _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static GoRouter? _router;

  // Section 20 (Memory and Resource Safety) hardening: `init()` wires up
  // three long-lived stream listeners (token refresh, foreground messages,
  // notification taps). Nothing previously guarded against `init()` being
  // invoked more than once in the same process, in which case each call
  // would register another set of listeners on top of the existing ones —
  // the exact "same listener added more than once" hazard the project's
  // own Memory/Resource Safety and Performance docs call out for Firebase
  // Messaging (duplicate deep-link navigation / duplicate local
  // notifications per incoming message). `init()` is currently only called
  // once, from `AppInitializer`, so this guard is defense-in-depth rather
  // than a fix for an observed production duplication — but it makes the
  // service safe against any future call site (retry logic, a
  // re-initialization flow, etc.) that invokes it again.
  static bool _initialized = false;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _onMessageSubscription;
  static StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;

  /// Deep-link target for a notification tap that arrived before the
  /// router was registered (see [_deepLinkTo] doc comment below).
  static String? _pendingDeepLinkPath;

  static const String _notificationsDeepLinkPath =
      '${AppRoutes.home}/notifications';

  /// Register the app router for deep link handling from notifications.
  ///
  /// `AppInitializer.init()` kicks off `FcmService.init()` with
  /// `unawaited(...)` *before* `runApp()`/the router exist (see
  /// `app_initializer.dart`). A cold-start notification tap resolved via
  /// `getInitialMessage()` can therefore complete before this method is
  /// ever called, which used to drop the deep link silently (`_router`
  /// was null, so `_router?.push(...)` was a no-op). Any such link is now
  /// queued in [_pendingDeepLinkPath] and replayed once the router becomes
  /// available.
  static void registerRouter(GoRouter router) {
    _router = router;
    final pending = _pendingDeepLinkPath;
    if (pending != null) {
      _pendingDeepLinkPath = null;
      // Defer to the next frame: this is invoked from EduZoneApp.build(),
      // and pushing synchronously here would trigger navigation while a
      // different widget is still mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _router?.push(pending);
      });
    }
  }

  /// Pushes [path] if the router is registered yet, otherwise queues it to
  /// be replayed by [registerRouter]. Centralizes the same-router-not-ready
  /// guard used by both the FCM and local-notification tap handlers below.
  static void _deepLinkTo(String path) {
    final router = _router;
    if (router != null) {
      router.push(path);
    } else {
      _pendingDeepLinkPath = path;
    }
  }

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await Firebase.initializeApp();
      
      final messaging = FirebaseMessaging.instance;
      
      // Request permission
      await messaging.requestPermission(
        
      );

      // Get initial token
      final token = await messaging.getToken();
      if (token != null) {
        await _saveToken(token);
      }

      // Listen to token refresh
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = messaging.onTokenRefresh.listen((newToken) {
        _saveToken(newToken);
      });

      await _setupLocalNotifications();
      
      // Handle foreground notifications
      await _onMessageSubscription?.cancel();
      _onMessageSubscription =
          FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showLocalNotification(message);
      });

      // Handle deep linking when tapping on notifications in background
      await _onMessageOpenedAppSubscription?.cancel();
      _onMessageOpenedAppSubscription =
          FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleDeepLink(message);
      });

      // Handle notification when app is completely terminated and then opened
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleDeepLink(initialMessage);
      }
      
    } catch (e, st) {
      // Firebase might not be configured yet during dev, ignore gracefully
      // for the user-facing flow (push notifications simply won't work),
      // but Section 15 ("notification subsystem" / "startup failures" are
      // explicitly in the audit list) requires this be observable in
      // production — previously this was debugPrint-only with zero Sentry
      // signal, so a broken FCM bootstrap on real devices (bad
      // google-services config, permission plugin mismatch, etc.) was
      // silently invisible.
      debugPrint('FCM Init Error: ${e.runtimeType}');
      GlobalErrorHandler.logError(e, st);
    }
  }

  /// Register/update FCM token for the currently authenticated user.
  static Future<void> registerCurrentUserToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _saveToken(token);
      }
    } catch (e) {
      debugPrint('Error getting FCM token on register: ${e.runtimeType}');
    }
  }

  /// Best-effort — every failure is swallowed below. Previously had no
  /// timeout on either call, so a stalled connection left this hanging
  /// indefinitely instead of failing fast. See Section 13 ("Networking
  /// Reliability") of the project instructions.
  static Future<void> _saveToken(String fcmToken) async {
    final uid = SupabaseService.client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final profile = await SupabaseService.client
          .from('users')
          .select('tenant_id')
          .eq('id', uid)
          .maybeSingle()
          .timeout(NetworkConfig.telemetryTimeout);
      final tenantId = profile?['tenant_id'] as String?;
      if (tenantId == null || tenantId.isEmpty) return;

      await SupabaseService.client.from('push_tokens').upsert({
        'user_id': uid,
        'tenant_id': tenantId,
        'token': fcmToken,
        'platform': DeviceInfoHelper.platform,
        'device_info': DeviceInfoHelper.deviceInfoJson,
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'token').timeout(NetworkConfig.telemetryTimeout);
    } catch (e) {
      debugPrint('Error saving FCM token: ${e.runtimeType}');
    }
  }

  static Future<void> deactivateToken() async {
    final uid = SupabaseService.client.auth.currentUser?.id;
    if (uid == null) return;

    try {
       await SupabaseService.client
          .from('push_tokens')
          .update({'is_active': false})
          .eq('user_id', uid);
    } catch (e) {
      debugPrint('Error deactivating FCM token: ${e.runtimeType}');
    }
  }

  static Future<void> initLocalNotifications() async {
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

      await _localNotificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (details) {
          _deepLinkTo(_notificationsDeepLinkPath);
        },
      );
    } catch (e, st) {
      // Local notification channel setup failing means notification taps
      // won't deep-link anywhere — a real UX regression with no prior
      // production observability. Same Section 15 rationale as init()
      // above.
      debugPrint('Local Notifications Init Error: ${e.runtimeType}');
      GlobalErrorHandler.logError(e, st);
    }
  }

  static Future<void> _setupLocalNotifications() async {
    await initLocalNotifications();
  }

  static void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && android != null) {
      _localNotificationsPlugin.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'eduzone_high_importance',
            'High Importance Notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    }
  }

  static void _handleDeepLink(RemoteMessage message) {
    _deepLinkTo(_notificationsDeepLinkPath);
  }
}
