import 'package:app/features/auth/domain/repositories/auth_repository.dart';
import 'package:app/features/auth/domain/usecases/login_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late LoginUser usecase;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    usecase = LoginUser(mockAuthRepository);
  });

  const tEmail = 'test@test.com';
  const tPassword = 'password123';
  test('should call login on the repository', () async {
    // arrange
    when(
      () => mockAuthRepository.login(tEmail, tPassword),
    ).thenAnswer((_) async {});

    // act
    await usecase(tEmail, tPassword);

    // assert
    verify(() => mockAuthRepository.login(tEmail, tPassword));
    verifyNoMoreInteractions(mockAuthRepository);
  });

  test('should throw exception when repository throws', () async {
    // arrange
    when(
      () => mockAuthRepository.login(tEmail, tPassword),
    ).thenThrow(Exception('Login failed'));

    // act & assert
    await expectLater(
      () => usecase(tEmail, tPassword),
      throwsException,
    );
    verify(() => mockAuthRepository.login(tEmail, tPassword));
  });
}
