import 'package:app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:app/features/notifications/domain/usecases/mark_as_read.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

void main() {
  late MarkAsRead usecase;
  late MockNotificationsRepository mockRepository;

  setUp(() {
    mockRepository = MockNotificationsRepository();
    usecase = MarkAsRead(mockRepository);
  });

  const tNotificationId = 'n1';
  const tUserId = 'u1';

  test('should call markAsRead when notificationId is provided', () async {
    // arrange
    when(
      () => mockRepository.markAsRead(any()),
    ).thenAnswer((_) async => const Right(null));

    // act
    final result = await usecase(tNotificationId, tUserId);

    // assert
    expect(result, const Right(null));
    verify(() => mockRepository.markAsRead(tNotificationId)).called(1);
    verifyNever(() => mockRepository.markAllAsRead(any()));
  });

  test('should call markAllAsRead when notificationId is null', () async {
    // arrange
    when(
      () => mockRepository.markAllAsRead(any()),
    ).thenAnswer((_) async => const Right(null));

    // act
    final result = await usecase(null, tUserId);

    // assert
    expect(result, const Right(null));
    verify(() => mockRepository.markAllAsRead(tUserId)).called(1);
    verifyNever(() => mockRepository.markAsRead(any()));
  });
}
