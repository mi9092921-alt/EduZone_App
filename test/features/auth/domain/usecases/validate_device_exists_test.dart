import 'package:app/features/auth/domain/repositories/auth_repository.dart';
import 'package:app/features/auth/domain/usecases/validate_device_exists.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late ValidateDeviceExists usecase;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    usecase = ValidateDeviceExists(mockAuthRepository);
  });

  const tUserId = 'user_123';
  const tFingerprint = 'device_fp_456';

  test(
    'should return true when the device fingerprint exists in the repository',
    () async {
      // arrange
      when(
        () => mockAuthRepository.validateDeviceExists(tUserId, tFingerprint),
      ).thenAnswer((_) async => true);

      // act
      final result = await usecase(tUserId, tFingerprint);

      // assert
      expect(result, isTrue);
      verify(
        () => mockAuthRepository.validateDeviceExists(tUserId, tFingerprint),
      ).called(1);
      verifyNoMoreInteractions(mockAuthRepository);
    },
  );

  test(
    'should return false when the device fingerprint does not exist in the repository',
    () async {
      // arrange
      when(
        () => mockAuthRepository.validateDeviceExists(tUserId, tFingerprint),
      ).thenAnswer((_) async => false);

      // act
      final result = await usecase(tUserId, tFingerprint);

      // assert
      expect(result, isFalse);
      verify(
        () => mockAuthRepository.validateDeviceExists(tUserId, tFingerprint),
      ).called(1);
      verifyNoMoreInteractions(mockAuthRepository);
    },
  );
}
