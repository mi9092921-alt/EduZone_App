import 'package:app/core/error/exceptions.dart';
import 'package:app/core/error/failures.dart';
import 'package:app/features/notifications/data/datasources/notifications_remote_ds.dart';
import 'package:app/features/notifications/data/repositories/notifications_repo_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationsRemoteDataSource extends Mock
    implements NotificationsRemoteDataSource {}

void main() {
  late NotificationsRepositoryImpl repository;
  late MockNotificationsRemoteDataSource mockDataSource;

  setUp(() {
    mockDataSource = MockNotificationsRemoteDataSource();
    repository = NotificationsRepositoryImpl(mockDataSource);
  });

  group('getNotifications', () {
    test(
      'should map DateTime timestamps without returning ServerFailure',
      () async {
        final createdAt = DateTime.utc(2026, 6, 24, 12);

        when(() => mockDataSource.getNotifications('user1')).thenAnswer(
          (_) async => [
            {
              'id': 'id1',
              'user_id': 'user1',
              'notification_id': 'notification1',
              'tenant_id': 'tenant1',
              'is_read': false,
              'read_at': null,
              'created_at': createdAt,
              'notification': {
                'title': 'Test notification',
                'body': 'Test notification body',
              },
            },
          ],
        );

        final result = await repository.getNotifications('user1');

        expect(result, isA<Right<Failure, dynamic>>());
        result.match(
          (_) => fail('Expected notifications to map successfully'),
          (notifications) {
            expect(notifications.single.createdAt, createdAt);
            expect(notifications.single.title, 'Test notification');
          },
        );
      },
    );
  });

  group('markAsRead', () {
    test('should return Right(null) when data source succeeds', () async {
      when(
        () => mockDataSource.markAsRead('id1'),
      ).thenAnswer((_) async => Future.value());

      final result = await repository.markAsRead('id1');

      expect(result, isA<Right<Failure, void>>());
    });

    test('should return Left(ServerFailure) on exception', () async {
      when(
        () => mockDataSource.markAsRead('id1'),
      ).thenThrow(const ServerException('Failed'));

      final result = await repository.markAsRead('id1');

      expect(result, isA<Left<Failure, void>>());
    });
  });

  group('markAllAsRead', () {
    test('should return Right(null) when data source succeeds', () async {
      when(
        () => mockDataSource.markAllAsRead('user1'),
      ).thenAnswer((_) async => Future.value());

      final result = await repository.markAllAsRead('user1');

      expect(result, isA<Right<Failure, void>>());
    });
  });
}
