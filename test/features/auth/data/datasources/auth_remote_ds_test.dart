import 'package:app/core/error/exceptions.dart';
import 'package:app/features/auth/data/datasources/auth_remote_ds.dart';
import 'package:app/features/auth/domain/entities/bind_device_result.dart';
import 'package:app/features/auth/domain/enums/account_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockRpcBuilder extends Mock implements PostgrestFilterBuilder<dynamic> {}

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockAuth;
  late AuthRemoteDataSource dataSource;

  // Stubs rpc(name) to resolve with [value] when awaited.
  // checkUserAccess calls .timeout() on the builder, so we stub that too.
  void stubRpc(String name, dynamic value, {bool withParams = false}) {
    final builder = MockRpcBuilder();
    if (withParams) {
      when(() => mockClient.rpc(name, params: any(named: 'params')))
          .thenAnswer((_) => builder);
    } else {
      when(() => mockClient.rpc(name)).thenAnswer((_) => builder);
    }
    when(() => builder.timeout(any())).thenAnswer((_) => builder);
    when<dynamic>(
      () => builder.then<dynamic>(any(), onError: any(named: 'onError')),
    ).thenAnswer((inv) {
      final onValue = inv.positionalArguments[0] as dynamic Function(dynamic);
      return Future<dynamic>.value(value).then(onValue);
    });
  }

  void stubRpcThrows(String name, Object error, {bool withParams = false}) {
    if (withParams) {
      when(() => mockClient.rpc(name, params: any(named: 'params')))
          .thenThrow(error);
    } else {
      when(() => mockClient.rpc(name)).thenThrow(error);
    }
  }

  setUp(() {
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    when(() => mockClient.auth).thenReturn(mockAuth);
    dataSource = AuthRemoteDataSource(mockClient);
  });

  group('checkUserAccess', () {
    test('returns active status when allowed is true', () async {
      stubRpc('check_user_access', {'allowed': true});

      final result = await dataSource.checkUserAccess();

      expect(result.status, AccountStatus.active);
      expect(result.isAllowed, isTrue);
    });

    test('returns banned status when allowed is false', () async {
      stubRpc('check_user_access', {'allowed': false, 'reason': 'account_banned'});

      final result = await dataSource.checkUserAccess();

      expect(result.status, AccountStatus.banned);
      expect(result.isAllowed, isFalse);
    });

    test('fails closed when response is null', () async {
      stubRpc('check_user_access', null);

      await expectLater(
        () => dataSource.checkUserAccess(),
        throwsA(isA<ServerException>()),
      );
    });

    test('throws ServerException on PostgrestException', () async {
      stubRpcThrows('check_user_access', const PostgrestException(message: 'DB error'));

      await expectLater(
        () => dataSource.checkUserAccess(),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('bindDevice', () {
    const tDeviceId = 'device-123';
    const tPlatform = 'android';
    const tDeviceInfo = {'model': 'Pixel 7'};

    test('returns verified status when RPC returns verified', () async {
      stubRpc('bind_device_for_current_user', {'status': 'verified'},
          withParams: true);

      final result =
          await dataSource.bindDevice(tDeviceId, tDeviceInfo, tPlatform);

      expect(result.status, BindDeviceStatus.verified);
    });

    test('returns bound status for non-verified response', () async {
      stubRpc('bind_device_for_current_user', {'status': 'bound'},
          withParams: true);

      final result =
          await dataSource.bindDevice(tDeviceId, tDeviceInfo, tPlatform);

      expect(result.status, BindDeviceStatus.bound);
    });

    test('passes fingerprint version to bind device RPC', () async {
      const versionedDeviceInfo = {
        'model': 'Pixel 7',
        'fingerprint_version': 'v2',
      };
      stubRpc('bind_device_for_current_user', {'status': 'verified'},
          withParams: true);

      await dataSource.bindDevice(tDeviceId, versionedDeviceInfo, tPlatform);

      final captured = verify(
        () => mockClient.rpc(
          'bind_device_for_current_user',
          params: captureAny(named: 'params'),
        ),
      ).captured.single as Map<String, dynamic>;

      expect(captured['p_device_id'], tDeviceId);
      expect(captured['p_device_info'], versionedDeviceInfo);
      expect(captured['p_fingerprint_version'], 'v2');
      expect(captured['p_platform'], tPlatform);
    });

    test('throws MaxDevicesReachedException on MAX_DEVICES_REACHED', () async {
      stubRpcThrows(
        'bind_device_for_current_user',
        const PostgrestException(message: 'MAX_DEVICES_REACHED'),
        withParams: true,
      );

      await expectLater(
        () => dataSource.bindDevice(tDeviceId, tDeviceInfo, tPlatform),
        throwsA(isA<MaxDevicesReachedException>()),
      );
    });
  });

  group('login', () {
    const tEmail = 'test@example.com';
    const tPassword = 'password123';

    test(
      'throws NoInternetException when AuthRetryableFetchException has no statusCode '
      '(real DNS/socket failure, e.g. FLUTTER-2)',
      () async {
        when(
          () => mockAuth.signInWithPassword(
            email: tEmail,
            password: tPassword,
          ),
        ).thenThrow(
          AuthRetryableFetchException(
            message:
                'ClientException with SocketException: Failed host lookup',
          ),
        );

        await expectLater(
          () => dataSource.login(tEmail, tPassword),
          throwsA(isA<NoInternetException>()),
        );
      },
    );

    test(
      'throws ServerException (not NoInternetException) when '
      'AuthRetryableFetchException carries a 5xx statusCode from Supabase',
      () async {
        when(
          () => mockAuth.signInWithPassword(
            email: tEmail,
            password: tPassword,
          ),
        ).thenThrow(
          AuthRetryableFetchException(
            message: 'Internal Server Error',
            statusCode: '500',
          ),
        );

        await expectLater(
          () => dataSource.login(tEmail, tPassword),
          throwsA(isA<ServerException>()),
        );
      },
    );

    test('throws InvalidCredentialsException when AuthException contains invalid credentials', () async {
      when(
        () => mockAuth.signInWithPassword(
          email: tEmail,
          password: tPassword,
        ),
      ).thenThrow(const AuthException('Invalid login credentials'));

      await expectLater(
        () => dataSource.login(tEmail, tPassword),
        throwsA(isA<InvalidCredentialsException>()),
      );
    });
  });
}
