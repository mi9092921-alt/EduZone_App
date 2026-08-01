import 'package:app/features/auth/domain/repositories/auth_repository.dart';
import 'package:app/features/auth/domain/usecases/logout_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late LogoutUser usecase;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    usecase = LogoutUser(mockAuthRepository);
  });

  test('should call logout on the repository', () async {
    // arrange
    when(() => mockAuthRepository.logout()).thenAnswer((_) async {});

    // act
    await usecase();

    // assert
    verify(() => mockAuthRepository.logout());
    verifyNoMoreInteractions(mockAuthRepository);
  });
}
