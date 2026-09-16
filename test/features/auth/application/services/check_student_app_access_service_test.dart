import 'dart:async';
import 'dart:io';

import 'package:app/features/auth/application/services/check_student_app_access_service.dart';
import 'package:app/features/auth/data/datasources/auth_remote_ds.dart';
import 'package:app/features/auth/domain/entities/user_access.dart';
import 'package:app/features/auth/domain/enums/account_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

// Kept only because the service constructor still takes a SupabaseClient
// for REALTIME channel lifecycle; no test path here touches channels.
class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

void main() {
  late MockSupabaseClient supabase;
  late MockAuthRemoteDataSource dataSource;
  late List<String> deniedReasons;
  late List<UserAccess> restrictedAccesses;

  // Mutable holders so setUp can register stubs once with thenAnswer,
  // and individual tests simply update these variables. This avoids the
  // "Cannot call `when` within a stub response" mocktail guard that fires
  // when when() is called mid-test after setUp stubs fire.
  late Map<String, dynamic>? mockRpcResponse;
  late int? mockJwtVersion;
  Object? checkError; // when non-null, the raw check throws this

  setUp(() {
    supabase = MockSupabaseClient();
    dataSource = MockAuthRemoteDataSource();
    deniedReasons = [];
    restrictedAccesses = [];

    // Default values — overridden per-test by reassigning the variables above.
    mockRpcResponse = {'token_version': 5, 'allowed': true};
    mockJwtVersion = 5;
    checkError = null;

    when(() => dataSource.checkStudentAppAccessRaw()).thenAnswer((_) async {
      final error = checkError;
      if (error != null) throw error;
      return mockRpcResponse;
    });
    when(() => dataSource.currentJwtTokenVersion)
        .thenAnswer((_) => mockJwtVersion);
  });

  CheckStudentAppAccessService buildService() {
    return CheckStudentAppAccessService(
      supabase: supabase,
      authRemoteDataSource: dataSource,
      onAccessDenied: ({required String reason}) => deniedReasons.add(reason),
      onAccessRestricted: ({required UserAccess access}) =>
          restrictedAccesses.add(access),
    );
  }

  group('missing jwtVersion strike logic', () {
    test(
        'access denied callback fires only after three consecutive missing '
        'jwtVersion checks, not before', () async {
      // mockJwtVersion == null stands for "JWT missing/unparseable
      // token_version" (the datasource getter resolves malformed tokens to
      // null — see the parsing fuzz group in auth_remote_ds_test).
      // mockRpcResponse already returns token_version: 5.
      mockJwtVersion = null;

      final service = buildService();

      await service.checkNow(); // strike 1
      expect(deniedReasons, isEmpty, reason: 'should not deny on strike 1');

      await service.checkNow(); // strike 2
      expect(deniedReasons, isEmpty, reason: 'should not deny on strike 2');

      await service.checkNow(); // strike 3 → force logout
      expect(deniedReasons, ['token_version_mismatch']);
      expect(deniedReasons.length, 1,
          reason: 'callback should fire exactly once, not repeatedly');
    });

    test('strike count resets once a valid jwtVersion is observed again',
        () async {
      final service = buildService();

      // Two strikes with missing jwtVersion.
      mockJwtVersion = null;
      await service.checkNow();
      await service.checkNow();
      expect(deniedReasons, isEmpty);

      // A valid, in-sync JWT arrives — should reset the strike counter.
      mockJwtVersion = 5;
      await service.checkNow();
      expect(deniedReasons, isEmpty);

      // Two more missing-jwtVersion checks — should NOT trigger force logout
      // yet, because the counter reset (would only trigger on a 3rd fresh
      // strike, not the 2nd).
      mockJwtVersion = null;
      await service.checkNow();
      await service.checkNow();
      expect(deniedReasons, isEmpty,
          reason: 'counter should have reset after the valid JWT check');
    });

    test('dbTokenVersion > jwtVersion still forces immediate logout',
        () async {
      mockRpcResponse = {'token_version': 9, 'allowed': true};
      mockJwtVersion = 3;

      final service = buildService();
      await service.checkNow();

      expect(deniedReasons, ['token_version_mismatch']);
    });
  });

  group('connectivity failure during check (CHECKUSERACCESS-BUG-01)', () {
    // Production incident: a device with no network at all makes the
    // check RPC fail with a DNS/socket-level error (`http.ClientException`
    // wrapping a `SocketException`/`OSError` — never even reaches Supabase,
    // so it is not a `PostgrestException`) on every 5-minute poll for as
    // long as the device stays offline. This must never crash the polling
    // loop and must never be treated as a real access denial/forced logout
    // — a network blip is not the server saying "no". (The datasource now
    // surfaces raw transport errors; the service's catch block classifies
    // them via NetworkExceptionMapper.)
    test(
        'ClientException wrapping a SocketException does not throw and '
        'does not deny access', () async {
      checkError = http.ClientException(
        'ClientException with SocketException: Failed host lookup: '
        "'evmrahlzcgqgjhwvxzih.supabase.co' (OS Error: No address "
        'associated with hostname, errno = 7)',
      );

      final service = buildService();

      await expectLater(service.checkNow(), completes);
      expect(deniedReasons, isEmpty);
      expect(restrictedAccesses, isEmpty);
    });

    test('a plain SocketException also does not throw or deny access',
        () async {
      checkError = const SocketException('Network is unreachable');

      final service = buildService();

      await expectLater(service.checkNow(), completes);
      expect(deniedReasons, isEmpty);
    });

    test('a TimeoutException also does not throw or deny access', () async {
      checkError = TimeoutException('check_student_app_access');

      final service = buildService();

      await expectLater(service.checkNow(), completes);
      expect(deniedReasons, isEmpty);
    });

    test('connectivity failures do not corrupt the missing-jwtVersion '
        'strike counter for the next successful check', () async {
      // mockJwtVersion defaults to 5 (in sync), so a *successful* response
      // would normally reset the counter. A failed check must not silently
      // consume/advance anything either way.
      checkError = const SocketException('Network is unreachable');
      final service = buildService();

      await service.checkNow(); // network failure — ignored
      await service.checkNow(); // network failure — ignored

      // Connectivity returns; the check now succeeds again — but with a
      // missing jwtVersion, so successes start counting strikes afresh.
      checkError = null;
      mockJwtVersion = null;

      await service.checkNow(); // strike 1 (missing jwtVersion)
      await service.checkNow(); // strike 2
      expect(deniedReasons, isEmpty,
          reason: 'two network failures + two real strikes must not have '
              'been conflated into three strikes');

      await service.checkNow(); // strike 3 -> forced logout
      expect(deniedReasons, ['token_version_mismatch']);
    });
  });

  group('stale async security callbacks', () {
    test('a check that completes after stop cannot force access denial',
        () async {
      final completer = Completer<Map<String, dynamic>?>();
      when(() => dataSource.checkStudentAppAccessRaw())
          .thenAnswer((_) => completer.future);
      mockJwtVersion = 5;

      final service = buildService();
      final pending = service.checkNow();
      service.stop();
      completer.complete({'token_version': 9, 'allowed': true});

      await pending;
      expect(deniedReasons, isEmpty);
    });
  });

  group('restricted states without logout', () {
    test('maintenance_mode emits restricted access without denied callback',
        () async {
      mockRpcResponse = {
        'allowed': false,
        'reason': 'maintenance_mode',
        'token_version': 5,
      };

      final service = buildService();
      await service.checkNow();

      expect(deniedReasons, isEmpty);
      expect(restrictedAccesses.single.status, AccountStatus.maintenance);
    });

    test('app_locked emits restricted access without denied callback',
        () async {
      mockRpcResponse = {
        'allowed': false,
        'reason': 'app_locked',
        'token_version': 5,
      };

      final service = buildService();
      await service.checkNow();

      expect(deniedReasons, isEmpty);
      expect(restrictedAccesses.single.status, AccountStatus.appLocked);
    });
  });
}
