import 'package:app/features/auth/domain/entities/bind_device_result.dart';
import 'package:app/features/auth/domain/repositories/auth_repository.dart';
import 'package:app/features/auth/domain/usecases/bind_device.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late BindDevice usecase;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    usecase = BindDevice(mockAuthRepository);
  });

  const tDeviceId = 'dev123';
  const tDeviceInfo = {'model': 'iPhone 15'};
  const tPlatform = 'ios';
  const tResult = BindDeviceResult(status: BindDeviceStatus.bound);

  test('should call bindDevice on the repository', () async {
    // arrange
    when(
      () => mockAuthRepository.bindDevice(tDeviceId, tDeviceInfo, tPlatform),
    ).thenAnswer((_) async => tResult);

    // act
    final result = await usecase(tDeviceId, tDeviceInfo, tPlatform);

    // assert
    expect(result, tResult);
    verify(
      () => mockAuthRepository.bindDevice(tDeviceId, tDeviceInfo, tPlatform),
    );
    verifyNoMoreInteractions(mockAuthRepository);
  });
}
