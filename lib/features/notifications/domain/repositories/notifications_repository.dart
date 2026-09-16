import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../../../../shared/models/app_notification.dart';

abstract class NotificationsRepository {
  Future<Either<Failure, List<AppNotification>>> getNotifications(String userId);
  Stream<void> watchChanges(String userId);
  Future<Either<Failure, void>> markAsRead(String notificationId);
  Future<Either<Failure, void>> markAllAsRead(String userId);
}
