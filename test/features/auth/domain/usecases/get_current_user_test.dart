import 'package:app/features/auth/domain/entities/app_user.dart';
import 'package:app/features/auth/domain/repositories/auth_repository.dart';
import 'package:app/features/auth/domain/usecases/get_current_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late GetCurrentUser usecase;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    usecase = GetCurrentUser(mockAuthRepository);
  });

  const tUser = AppUser(
    id: '1',
    email: 'test@test.com',
    firstName: 'Test',
    lastName: 'User',
  );

  test('should call getCurrentUser on the repository and return the user', () async {
    // arrange
    when(
      () => mockAuthRepository.getCurrentUser(),
    ).thenAnswer((_) async => tUser);

    // act
    final result = await usecase();

    // assert
    expect(result, tUser);
    verify(() => mockAuthRepository.getCurrentUser());
    verifyNoMoreInteractions(mockAuthRepository);
  });

  test('should return null when no user is authenticated', () async {
    // arrange
    when(
      () => mockAuthRepository.getCurrentUser(),
    ).thenAnswer((_) async => null);

    // act
    final result = await usecase();

    // assert
    expect(result, isNull);
    verify(() => mockAuthRepository.getCurrentUser());
    verifyNoMoreInteractions(mockAuthRepository);
  });

  test('should propagate exception when repository throws', () async {
    // arrange
    when(
      () => mockAuthRepository.getCurrentUser(),
    ).thenThrow(Exception('Failed to fetch current user'));

    // act & assert
    await expectLater(
      () => usecase(),
      throwsException,
    );
    verify(() => mockAuthRepository.getCurrentUser());
  });
}