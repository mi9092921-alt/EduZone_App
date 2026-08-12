import 'package:app/core/services/device_service.dart';
import 'package:app/features/auth/application/services/auth_activity_sync_service.dart';
import 'package:app/features/auth/data/datasources/auth_remote_ds.dart';
import 'package:app/features/auth/domain/entities/app_user.dart';
import 'package:app/features/auth/domain/entities/bind_device_result.dart';
import 'package:app/features/auth/domain/usecases/bind_device.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockDeviceService extends Mock implements DeviceService {}

class MockBindDevice extends Mock implements BindDevice {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tUser = AppUser(
    id: 'user-1',
    email: 'test@example.com',
    tenantId: 'tenant-1',
    regionId: 'region-1',
  );

  late MockAuthRemoteDataSource mockRemoteDataSource;
  late MockDeviceService mockDeviceService;
  late MockBindDevice mockBindDevice;
  late AuthActivitySyncService service;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockRemoteDataSource = MockAuthRemoteDataSource();
    mockDeviceService = MockDeviceService();
    mockBindDevice = MockBindDevice();

    when(() => mockDeviceService.fingerprint).thenReturn('fp-123');
    when(() => mockDeviceService.deviceInfoJson)
        .thenReturn({'model': 'Pixel 8'});
    when(() => mockDeviceService.platform).thenReturn('android');

    when(
      () => mockRemoteDataSource.syncUserActivity(
        userId: any(named: 'userId'),
        tenantId: any(named: 'tenantId'),
        deviceFingerprint: any(named: 'deviceFingerprint'),
      ),
    ).thenAnswer((_) async {});

    when(
      () => mockRemoteDataSource.recordSession(
        userId: any(named: 'userId'),
        tenantId: any(named: 'tenantId'),
        deviceFingerprint: any(named: 'deviceFingerprint'),
        regionId: any(named: 'regionId'),
        userAgent: any(named: 'userAgent'),
      ),
    ).thenAnswer((_) async {});

    when(() => mockBindDevice(any(), any(), any())).thenAnswer(
      (_) async => const BindDeviceResult(status: BindDeviceStatus.bound),
    );

    service = AuthActivitySyncService(
      remoteDataSource: mockRemoteDataSource,
      deviceService: mockDeviceService,
      bindDevice: mockBindDevice,
    );
  });

  group('syncActivityAndSession — skipBind: true (login / resumed session)', () {
    test('syncs activity but does NOT record a new session', () async {
      await service.syncActivityAndSession(tUser, skipBind: true);

      verify(
        () => mockRemoteDataSource.syncUserActivity(
          userId: tUser.id,
          tenantId: tUser.tenantId,
          deviceFingerprint: 'fp-123',
        ),
      ).called(1);

      verifyNever(
        () => mockRemoteDataSource.recordSession(
          userId: any(named: 'userId'),
          tenantId: any(named: 'tenantId'),
          deviceFingerprint: any(named: 'deviceFingerprint'),
          regionId: any(named: 'regionId'),
          userAgent: any(named: 'userAgent'),
        ),
      );

      verifyNever(() => mockBindDevice(any(), any(), any()));
    });
  });

  group('syncActivityAndSession — skipBind: false (fresh flow)', () {
    test('binds the device, syncs activity, and records a session', () async {
      await service.syncActivityAndSession(tUser);

      verify(
        () => mockBindDevice('fp-123', {'model': 'Pixel 8'}, 'android'),
      ).called(1);

      verify(
        () => mockRemoteDataSource.syncUserActivity(
          userId: tUser.id,
          tenantId: tUser.tenantId,
          deviceFingerprint: 'fp-123',
        ),
      ).called(1);

      verify(
        () => mockRemoteDataSource.recordSession(
          userId: tUser.id,
          tenantId: tUser.tenantId,
          deviceFingerprint: 'fp-123',
          regionId: tUser.regionId,
          userAgent: 'android: Pixel 8',
        ),
      ).called(1);
    });

    test('falls back to "Unknown" in userAgent when model is missing', () async {
      when(() => mockDeviceService.deviceInfoJson).thenReturn({});

      await service.syncActivityAndSession(tUser);

      verify(
        () => mockRemoteDataSource.recordSession(
          userId: tUser.id,
          tenantId: tUser.tenantId,
          deviceFingerprint: 'fp-123',
          regionId: tUser.regionId,
          userAgent: 'android: Unknown',
        ),
      ).called(1);
    });
  });

  group('error handling', () {
    test('swallows exceptions instead of rethrowing (best-effort sync)', () async {
      when(
        () => mockRemoteDataSource.syncUserActivity(
          userId: any(named: 'userId'),
          tenantId: any(named: 'tenantId'),
          deviceFingerprint: any(named: 'deviceFingerprint'),
        ),
      ).thenThrow(Exception('network down'));

      await expectLater(
        service.syncActivityAndSession(tUser, skipBind: true),
        completes,
      );
    });

    test('a bindDevice failure is also swallowed and does not stop the caller', () async {
      when(() => mockBindDevice(any(), any(), any()))
          .thenThrow(Exception('max devices reached'));

      await expectLater(
        service.syncActivityAndSession(tUser),
        completes,
      );

      // Because bindDevice threw, activity sync/recordSession never ran.
      verifyNever(
        () => mockRemoteDataSource.syncUserActivity(
          userId: any(named: 'userId'),
          tenantId: any(named: 'tenantId'),
          deviceFingerprint: any(named: 'deviceFingerprint'),
        ),
      );
    });
  });
}
