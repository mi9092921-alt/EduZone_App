import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/services/push_token_registration_service.dart';
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
      
      // Permission is requested from the user-facing permissions surface,
      // not during cold start. This prevents an unexplained OS prompt before
      // login/home and keeps denied permission recoverable from Settings.

      // Get initial token
      final token = await messaging.getToken();
      if (token != null) {
        await PushTokenRegistrationService.registerCurrentUserToken();
      }

      // Listen to token refresh
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = messaging.onTokenRefresh.listen((_) {
        unawaited(PushTokenRegistrationService.registerCurrentUserToken());
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
      // Permit a later foreground retry after a transient Firebase/plugin
      // startup failure. Keeping this true would permanently disable push
      // setup for the rest of the process.
      _initialized = false;
    }
  }

  /// Register/update FCM token for the currently authenticated user.
  static Future<void> registerCurrentUserToken() async {
    await PushTokenRegistrationService.registerCurrentUserToken();
  }

  static Future<void> deactivateToken() async {
    await PushTokenRegistrationService.deactivateCurrentUserToken();
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

    if (notification != null) {
      unawaited(_localNotificationsPlugin.show(
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
      ).catchError((Object error, StackTrace stack) {
        GlobalErrorHandler.logError(error, stack);
      }));
    }
  }

  static void _handleDeepLink(RemoteMessage message) {
    _deepLinkTo(_notificationsDeepLinkPath);
  }
}
