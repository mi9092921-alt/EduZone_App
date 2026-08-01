import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../repositories/notifications_repository.dart';

class MarkAsRead {
  final NotificationsRepository repository;

  MarkAsRead(this.repository);

  Future<Either<Failure, void>> call(String? notificationId, String userId) async {
    if (notificationId != null) {
      return await repository.markAsRead(notificationId);
    } else {
      return await repository.markAllAsRead(userId);
    }
  }
}
