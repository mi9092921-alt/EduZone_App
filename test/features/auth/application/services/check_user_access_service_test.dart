import 'dart:async';
import 'dart:convert';

import 'package:app/features/auth/application/services/check_user_access_service.dart';
import 'package:app/features/auth/domain/entities/user_access.dart';
import 'package:app/features/auth/domain/enums/account_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockSession extends Mock implements Session {}

/// `SupabaseClient.rpc()` returns `PostgrestFilterBuilder<dynamic>`, not
/// a plain `Future<Map>` — it only *behaves* like a Future when awaited
/// (it implements `Future<T>` and delegates via `then`). mocktail's
/// `thenAnswer`/`thenReturn` need the exact declared return type, so a bare
/// `Future<Map>` doesn't satisfy it (this is what caused
/// `argument_type_not_assignable`). This Fake wraps a value and only
/// overrides `then`, which is all `await` needs to work.
class _FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  _FakePostgrestFilterBuilder(this._value);
  final T _value;

  @override
  Future<S> then<S>(
    FutureOr<S> Function(T value) onValue, {
    Function? onError,
  }) {
    return Future<T>.value(_value).then(onValue, onError: onError);
  }
}

/// Builds a fake (unsigned, not cryptographically valid — signature isn't
/// checked client-side) JWT string with the given payload claims, matching
/// how `_currentJwtTokenVersion` decodes tokens (base64url, no padding).
String _fakeJwt(Map<String, dynamic> payload) {
  String encode(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final header = encode({'alg': 'none', 'typ': 'JWT'});
  final body = encode(payload);
  return '$header.$body.';
}

void main() {
  late MockSupabaseClient supabase;
  late MockGoTrueClient auth;
  late MockSession session;
  late List<String> deniedReasons;
  late List<UserAccess> restrictedAccesses;

  // Mutable holders so setUp can register stubs once with thenAnswer,
  // and individual tests simply update these variables.
  // This avoids the "Cannot call `when` within a stub response" mocktail
  // guard that fires when when() is called mid-test after setUp stubs fire.
  late Map<String, dynamic> mockRpcResponse;
  late String mockAccessToken;

  setUp(() {
    supabase = MockSupabaseClient();
    auth = MockGoTrueClient();
    session = MockSession();
    deniedReasons = [];
    restrictedAccesses = [];

    // Default values — overridden per-test by reassigning the variables above.
    mockRpcResponse = {'token_version': 5, 'allowed': true};
    mockAccessToken = _fakeJwt({'sub': 'user-123'});

    when(() => supabase.auth).thenReturn(auth);
    when(() => auth.currentSession).thenReturn(session);
    // thenAnswer (not thenReturn) — rpc returns a Future-like builder.
    when(() => session.accessToken).thenAnswer((_) => mockAccessToken);
    when(() => supabase.rpc('check_user_access')).thenAnswer(
      (_) => _FakePostgrestFilterBuilder<Map<String, dynamic>>(mockRpcResponse),
    );
  });

  CheckUserAccessService buildService() {
    return CheckUserAccessService(
      supabase: supabase,
      onAccessDenied: ({required String reason}) => deniedReasons.add(reason),
      onAccessRestricted: ({required UserAccess access}) =>
          restrictedAccesses.add(access),
    );
  }

  group('missing jwtVersion strike logic', () {
    test(
        'access denied callback fires only after three consecutive missing '
        'jwtVersion checks, not before', () async {
      // JWT with no token_version claim → jwtVersion resolves to null.
      // mockAccessToken already defaults to a JWT with no token_version.
      // mockRpcResponse already returns token_version: 5.

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

      // Two strikes with missing jwtVersion (default mockAccessToken has none).
      await service.checkNow();
      await service.checkNow();
      expect(deniedReasons, isEmpty);

      // A valid, in-sync JWT arrives — should reset the strike counter.
      mockAccessToken =
          _fakeJwt({'sub': 'user-123', 'token_version': 5});
      await service.checkNow();
      expect(deniedReasons, isEmpty);

      // Two more missing-jwtVersion checks — should NOT trigger force logout
      // yet, because the counter reset (would only trigger on a 3rd fresh
      // strike, not the 2nd).
      mockAccessToken = _fakeJwt({'sub': 'user-123'});
      await service.checkNow();
      await service.checkNow();
      expect(deniedReasons, isEmpty,
          reason: 'counter should have reset after the valid JWT check');
    });

    test('dbTokenVersion > jwtVersion still forces immediate logout',
        () async {
      mockRpcResponse = {'token_version': 9, 'allowed': true};
      mockAccessToken = _fakeJwt({'sub': 'user-123', 'token_version': 3});

      final service = buildService();
      await service.checkNow();

      expect(deniedReasons, ['token_version_mismatch']);
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
      mockAccessToken = _fakeJwt({'sub': 'user-123', 'token_version': 5});

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
      mockAccessToken = _fakeJwt({'sub': 'user-123', 'token_version': 5});

      final service = buildService();
      await service.checkNow();

      expect(deniedReasons, isEmpty);
      expect(restrictedAccesses.single.status, AccountStatus.appLocked);
    });
  });
}
