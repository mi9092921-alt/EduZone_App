import 'package:app/features/auth/domain/entities/user_access.dart';
import 'package:app/features/auth/domain/enums/account_status.dart';
import 'package:app/features/auth/domain/repositories/auth_repository.dart';
import 'package:app/features/auth/domain/usecases/check_student_app_access.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late CheckStudentAppAccess usecase;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    usecase = CheckStudentAppAccess(mockAuthRepository);
  });

  const tAccess = UserAccess(status: AccountStatus.active);

  test('should check access via repository and return UserAccess', () async {
    // arrange
    when(
      () => mockAuthRepository.checkStudentAppAccess(),
    ).thenAnswer((_) async => tAccess);

    // act
    final result = await usecase();

    // assert
    expect(result, tAccess);
    verify(() => mockAuthRepository.checkStudentAppAccess());
    verifyNoMoreInteractions(mockAuthRepository);
  });
}
