import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/device_info_helper.dart';

class FcmService {
  static final _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static GoRouter? _router;

  /// Register the app router for deep link handling from notifications.
  static void registerRouter(GoRouter router) {
    _router = router;
  }

  static Future<void> init() async {
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
      messaging.onTokenRefresh.listen((newToken) {
        _saveToken(newToken);
      });

      await _setupLocalNotifications();
      
      // Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showLocalNotification(message);
      });

      // Handle deep linking when tapping on notifications in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleDeepLink(message);
      });

      // Handle notification when app is completely terminated and then opened
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleDeepLink(initialMessage);
      }
      
    } catch (e) {
      // Firebase might not be configured yet during dev, ignore gracefully
      debugPrint('FCM Init Error: $e');
    }
  }

  static Future<void> _saveToken(String fcmToken) async {
    final uid = SupabaseService.client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final profile = await SupabaseService.client
          .from('users')
          .select('tenant_id')
          .eq('id', uid)
          .maybeSingle();
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
      }, onConflict: 'token');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
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
      debugPrint('Error deactivating FCM token: $e');
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
          _router?.push('${AppRoutes.home}/notifications');
        },
      );
    } catch (e) {
      debugPrint('Local Notifications Init Error: $e');
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
    _router?.push('${AppRoutes.home}/notifications');
  }
}
