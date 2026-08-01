import 'package:app/features/auth/domain/entities/user_access.dart';
import 'package:app/features/auth/domain/enums/account_status.dart';
import 'package:app/features/auth/domain/repositories/auth_repository.dart';
import 'package:app/features/auth/domain/usecases/check_user_access.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late CheckUserAccess usecase;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    usecase = CheckUserAccess(mockAuthRepository);
  });

  const tAccess = UserAccess(status: AccountStatus.active);

  test('should check access via repository and return UserAccess', () async {
    // arrange
    when(
      () => mockAuthRepository.checkUserAccess(),
    ).thenAnswer((_) async => tAccess);

    // act
    final result = await usecase();

    // assert
    expect(result, tAccess);
    verify(() => mockAuthRepository.checkUserAccess());
    verifyNoMoreInteractions(mockAuthRepository);
  });
}
