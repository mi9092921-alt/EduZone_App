import 'package:app/features/auth/data/datasources/auth_remote_ds.dart';
import 'package:app/features/auth/data/repositories/auth_repo_impl.dart';
import 'package:app/features/auth/domain/entities/app_user.dart';
import 'package:app/features/auth/domain/entities/bind_device_result.dart';
import 'package:app/features/auth/domain/entities/user_access.dart';
import 'package:app/features/auth/domain/enums/account_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

void main() {
  late AuthRepositoryImpl repository;
  late MockAuthRemoteDataSource mockDataSource;

  setUp(() {
    mockDataSource = MockAuthRemoteDataSource();
    repository = AuthRepositoryImpl(mockDataSource);
  });

  const tEmail = 'test@example.com';
  const tPassword = 'password123';
  const tUserId = 'user-123';
  const tDeviceId = 'device-123';
  const tPlatform = 'android';
  const tDeviceInfo = {'model': 'Test Device'};

  const tUser = AppUser(id: tUserId, email: tEmail);

  const tUserAccess = UserAccess(status: AccountStatus.active);
  const tBindResult = BindDeviceResult(status: BindDeviceStatus.bound);

  group('checkStudentAppAccess', () {
    test('should forward call to data source and return result', () async {
      when(
        () => mockDataSource.checkStudentAppAccess(),
      ).thenAnswer((_) async => tUserAccess);

      final result = await repository.checkStudentAppAccess();

      expect(result, equals(tUserAccess));
      verify(() => mockDataSource.checkStudentAppAccess()).called(1);
      verifyNoMoreInteractions(mockDataSource);
    });
  });

  group('login', () {
    test('should forward call to data source and return user', () async {
      when(
        () => mockDataSource.login(tEmail, tPassword),
      ).thenAnswer((_) async => tUser);

      final result = await repository.login(tEmail, tPassword);

      expect(result, equals(tUser));
      verify(() => mockDataSource.login(tEmail, tPassword)).called(1);
      verifyNoMoreInteractions(mockDataSource);
    });
  });

  group('bindDevice', () {
    test('should forward call to data source and return result', () async {
      when(
        () => mockDataSource.bindDevice(tDeviceId, tDeviceInfo, tPlatform),
      ).thenAnswer((_) async => tBindResult);

      final result = await repository.bindDevice(
        tDeviceId,
        tDeviceInfo,
        tPlatform,
      );

      expect(result, equals(tBindResult));
      verify(
        () => mockDataSource.bindDevice(tDeviceId, tDeviceInfo, tPlatform),
      ).called(1);
      verifyNoMoreInteractions(mockDataSource);
    });
  });

  group('logout', () {
    test('should forward call to data source', () async {
      when(() => mockDataSource.logout()).thenAnswer((_) async => {});

      await repository.logout();

      verify(() => mockDataSource.logout()).called(1);
      verifyNoMoreInteractions(mockDataSource);
    });
  });

  group('validateDeviceExists', () {
    test('should forward call to data source and return result', () async {
      const tFingerprint = 'fp-123';
      when(
        () => mockDataSource.validateDeviceExists(tUserId, tFingerprint),
      ).thenAnswer((_) async => true);

      final result = await repository.validateDeviceExists(
        tUserId,
        tFingerprint,
      );

      expect(result, isTrue);
      verify(
        () => mockDataSource.validateDeviceExists(tUserId, tFingerprint),
      ).called(1);
      verifyNoMoreInteractions(mockDataSource);
    });
  });

  group('getCurrentUser', () {
    test('should forward call to data source and return user', () async {
      when(
        () => mockDataSource.getCurrentUser(),
      ).thenAnswer((_) async => tUser);

      final result = await repository.getCurrentUser();

      expect(result, equals(tUser));
      verify(() => mockDataSource.getCurrentUser()).called(1);
      verifyNoMoreInteractions(mockDataSource);
    });
  });
}
