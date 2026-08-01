import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'fcm_service.dart';

part 'notification_service.g.dart';

abstract class NotificationService {
  Future<void> deactivateToken();
}

class FcmNotificationService implements NotificationService {
  @override
  Future<void> deactivateToken() => FcmService.deactivateToken();
}

@riverpod
NotificationService notificationService(Ref ref) {
  return FcmNotificationService();
}
