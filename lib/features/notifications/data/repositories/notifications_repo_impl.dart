import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_remote_ds.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsRemoteDataSource remoteDataSource;

  NotificationsRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, List<AppNotification>>> getNotifications(
    String userId,
  ) async {
    try {
      final results = await remoteDataSource.getNotifications(userId);
      return Right(
        results
            .map((json) => AppNotification.fromJson(_normalizeJson(json)))
            .toList(),
      );
    } catch (e) {
      return Left(failureFromError(e));
    }
  }

  Map<String, dynamic> _normalizeJson(Map<String, dynamic> json) {
    return json.map((key, value) {
      if (value is DateTime) {
        return MapEntry(key, value.toIso8601String());
      }
      return MapEntry(key, value);
    });
  }

  @override
  Stream<void> watchChanges(String userId) {
    return remoteDataSource.watchChanges(userId);
  }

  @override
  Future<Either<Failure, void>> markAsRead(String notificationId) async {
    try {
      await remoteDataSource.markAsRead(notificationId);
      return const Right(null);
    } catch (e) {
      return Left(failureFromError(e));
    }
  }

  @override
  Future<Either<Failure, void>> markAllAsRead(String userId) async {
    try {
      await remoteDataSource.markAllAsRead(userId);
      return const Right(null);
    } catch (e) {
      return Left(failureFromError(e));
    }
  }
}
