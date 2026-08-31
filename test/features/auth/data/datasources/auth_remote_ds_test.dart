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
  // checkStudentAppAccess calls .timeout() on the builder, so we stub that too.
  void stubRpc(String name, dynamic value, {bool withParams = false}) {
    final builder = MockRpcBuilder();
    if (withParams) {
      when(
        () => mockClient.rpc(name, params: any(named: 'params')),
      ).thenAnswer((_) => builder);
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
      when(
        () => mockClient.rpc(name, params: any(named: 'params')),
      ).thenThrow(error);
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

  group('checkStudentAppAccess', () {
    test('returns active status when allowed is true', () async {
      stubRpc('check_student_app_access', {'allowed': true});

      final result = await dataSource.checkStudentAppAccess();

      expect(result.status, AccountStatus.active);
      expect(result.isAllowed, isTrue);
    });

    test('returns banned status when allowed is false', () async {
      stubRpc('check_student_app_access', {
        'allowed': false,
        'reason': 'account_banned',
      });

      final result = await dataSource.checkStudentAppAccess();

      expect(result.status, AccountStatus.banned);
      expect(result.isAllowed, isFalse);
    });

    test('fails closed when response is null', () async {
      stubRpc('check_student_app_access', null);

      await expectLater(
        () => dataSource.checkStudentAppAccess(),
        throwsA(isA<ServerException>()),
      );
    });

    test('throws ServerException on PostgrestException', () async {
      stubRpcThrows(
        'check_student_app_access',
        const PostgrestException(message: 'DB error'),
      );

      await expectLater(
        () => dataSource.checkStudentAppAccess(),
        throwsA(isA<ServerException>()),
      );
    });

    test('preserves RLS recursion code from check_student_app_access', () async {
      stubRpcThrows(
        'check_student_app_access',
        const PostgrestException(
          message: 'infinite recursion detected in policy for relation "users"',
          code: '42P17',
        ),
      );

      await expectLater(
        () => dataSource.checkStudentAppAccess(),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            'RPC_RLS_RECURSION',
          ),
        ),
      );
    });
  });

  group('bindDevice', () {
    const tDeviceId = 'device-123';
    const tPlatform = 'android';
    const tDeviceInfo = {'model': 'Pixel 7'};

    test('returns verified status when RPC returns verified', () async {
      stubRpc('bind_device_for_current_user', {
        'status': 'verified',
      }, withParams: true);

      final result = await dataSource.bindDevice(
        tDeviceId,
        tDeviceInfo,
        tPlatform,
      );

      expect(result.status, BindDeviceStatus.verified);
    });

    test('returns bound status for non-verified response', () async {
      stubRpc('bind_device_for_current_user', {
        'status': 'bound',
      }, withParams: true);

      final result = await dataSource.bindDevice(
        tDeviceId,
        tDeviceInfo,
        tPlatform,
      );

      expect(result.status, BindDeviceStatus.bound);
    });

    test('passes fingerprint version to bind device RPC', () async {
      const versionedDeviceInfo = {
        'model': 'Pixel 7',
        'fingerprint_version': 'v2',
      };
      stubRpc('bind_device_for_current_user', {
        'status': 'verified',
      }, withParams: true);

      await dataSource.bindDevice(tDeviceId, versionedDeviceInfo, tPlatform);

      final captured =
          verify(
                () => mockClient.rpc(
                  'bind_device_for_current_user',
                  params: captureAny(named: 'params'),
                ),
              ).captured.single
              as Map<String, dynamic>;

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

    // AUTH-BUG-01 regression: before this fix, every post-auth RPC error
    // that wasn't MAX_DEVICES_REACHED / DEVICE_ALREADY_BOUND / RATE_LIMIT
    // collapsed into a single indistinguishable
    // `ServerException('Authentication backend request failed')`, which is
    // exactly why a missing GRANT (surfacing as 404/permission-denied) and
    // the users/user_roles RLS recursion (42P17) were both invisible in
    // logs -- they looked identical to any other failure. These tests
    // pin the specific `code` each known failure mode must carry so a
    // future regression is caught by the exception type/code, not just
    // "some ServerException got thrown".
    test(
      'throws ServerException with code AUTH_REQUIRED when RPC rejects '
      'with AUTH_REQUIRED (validate_user_session() failing server-side)',
      () async {
        stubRpcThrows(
          'bind_device_for_current_user',
          const PostgrestException(message: 'AUTH_REQUIRED'),
          withParams: true,
        );

        await expectLater(
          () => dataSource.bindDevice(tDeviceId, tDeviceInfo, tPlatform),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              'AUTH_REQUIRED',
            ),
          ),
        );
      },
    );

    test(
      'throws ServerException with code RPC_NOT_FOUND when PostgREST '
      'cannot find the function in its schema cache (the exact AUTH-BUG-01 '
      'symptom: missing EXECUTE grant / stale schema cache surfacing as 404)',
      () async {
        stubRpcThrows(
          'bind_device_for_current_user',
          const PostgrestException(
            message: 'function not found',
            code: 'PGRST202',
          ),
          withParams: true,
        );

        await expectLater(
          () => dataSource.bindDevice(tDeviceId, tDeviceInfo, tPlatform),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              'RPC_NOT_FOUND',
            ),
          ),
        );
      },
    );

    test(
      'throws ServerException with code RPC_PERMISSION_DENIED on a '
      'Postgres 42501 permission-denied error (missing EXECUTE grant)',
      () async {
        stubRpcThrows(
          'bind_device_for_current_user',
          const PostgrestException(
            message:
                'permission denied for function bind_device_for_current_user',
            code: '42501',
          ),
          withParams: true,
        );

        await expectLater(
          () => dataSource.bindDevice(tDeviceId, tDeviceInfo, tPlatform),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              'RPC_PERMISSION_DENIED',
            ),
          ),
        );
      },
    );

    test('throws ServerException with code RPC_RLS_RECURSION on a Postgres '
        '42P17 infinite-recursion error (the exact users/user_roles '
        'FORCE ROW LEVEL SECURITY symptom from AUTH-BUG-01)', () async {
      stubRpcThrows(
        'bind_device_for_current_user',
        const PostgrestException(
          message: 'infinite recursion detected in policy for relation "users"',
          code: '42P17',
        ),
        withParams: true,
      );

      await expectLater(
        () => dataSource.bindDevice(tDeviceId, tDeviceInfo, tPlatform),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            'RPC_RLS_RECURSION',
          ),
        ),
      );
    });

    test('throws ServerException with code TENANT_MISMATCH when RPC rejects '
        'with TENANT_MISMATCH', () async {
      stubRpcThrows(
        'bind_device_for_current_user',
        const PostgrestException(message: 'TENANT_MISMATCH'),
        withParams: true,
      );

      await expectLater(
        () => dataSource.bindDevice(tDeviceId, tDeviceInfo, tPlatform),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            'TENANT_MISMATCH',
          ),
        ),
      );
    });

    test('throws ServerException with code INVALID_DEVICE_ID when RPC rejects '
        'with INVALID_DEVICE_ID', () async {
      stubRpcThrows(
        'bind_device_for_current_user',
        const PostgrestException(message: 'INVALID_DEVICE_ID'),
        withParams: true,
      );

      await expectLater(
        () => dataSource.bindDevice(tDeviceId, tDeviceInfo, tPlatform),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            'INVALID_DEVICE_ID',
          ),
        ),
      );
    });

    test('throws ServerException with code INVALID_FINGERPRINT_VERSION when '
        'RPC rejects with INVALID_FINGERPRINT_VERSION', () async {
      stubRpcThrows(
        'bind_device_for_current_user',
        const PostgrestException(message: 'INVALID_FINGERPRINT_VERSION'),
        withParams: true,
      );

      await expectLater(
        () => dataSource.bindDevice(tDeviceId, tDeviceInfo, tPlatform),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            'INVALID_FINGERPRINT_VERSION',
          ),
        ),
      );
    });

    test('falls back to the raw PostgREST error code for anything else, '
        'never silently losing it', () async {
      stubRpcThrows(
        'bind_device_for_current_user',
        const PostgrestException(
          message: 'some unmapped failure',
          code: '99999',
        ),
        withParams: true,
      );

      await expectLater(
        () => dataSource.bindDevice(tDeviceId, tDeviceInfo, tPlatform),
        throwsA(isA<ServerException>().having((e) => e.code, 'code', '99999')),
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
          () => mockAuth.signInWithPassword(email: tEmail, password: tPassword),
        ).thenThrow(
          AuthRetryableFetchException(
            message: 'ClientException with SocketException: Failed host lookup',
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
          () => mockAuth.signInWithPassword(email: tEmail, password: tPassword),
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

    test(
      'throws InvalidCredentialsException when AuthException contains invalid credentials',
      () async {
        when(
          () => mockAuth.signInWithPassword(email: tEmail, password: tPassword),
        ).thenThrow(const AuthException('Invalid login credentials'));

        await expectLater(
          () => dataSource.login(tEmail, tPassword),
          throwsA(isA<InvalidCredentialsException>()),
        );
      },
    );
  });
}
