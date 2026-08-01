import 'package:app/features/notifications/domain/entities/app_notification.dart';
import 'package:app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:app/features/notifications/domain/usecases/get_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

void main() {
  late GetNotifications usecase;
  late MockNotificationsRepository mockRepository;

  setUp(() {
    mockRepository = MockNotificationsRepository();
    usecase = GetNotifications(mockRepository);
  });

  const tUserId = 'u123';
  final tNotifications = [
    AppNotification(
      id: 'n1',
      userId: tUserId,
      tenantId: 't1',
      createdAt: DateTime.now(),
      details: const NotificationDetails(
        title: 'Title',
        body: 'Body',
      ),
    ),
  ];

  test('should return list of notifications from the repository', () async {
    // arrange
    when(
      () => mockRepository.getNotifications(any()),
    ).thenAnswer((_) async => Right(tNotifications));

    // act
    final result = await usecase(tUserId);

    // assert
    expect(result, Right(tNotifications));
    verify(() => mockRepository.getNotifications(tUserId)).called(1);
    verifyNoMoreInteractions(mockRepository);
  });
}
