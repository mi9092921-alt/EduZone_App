import 'dart:async';

import 'package:app/core/error/exceptions.dart';
import 'package:app/core/feature_flags/data/feature_flag_remote_ds.dart';
import 'package:app/core/feature_flags/feature_flag_keys.dart';
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
  late MockRpcBuilder builder;
  late FeatureFlagRemoteDataSource repository;

  // Stubs rpc('evaluate_feature_flags', params: {...}) to resolve with
  // [value] when awaited. NetworkGuard.read calls .timeout() on the
  // builder, so that is stubbed too (same pattern as auth_remote_ds_test).
  void stubRpc(dynamic value) {
    when(
      () => mockClient.rpc(
        'evaluate_feature_flags',
        params: any(named: 'params'),
      ),
    ).thenAnswer((_) => builder);
    when(() => builder.timeout(any())).thenAnswer((_) => builder);
    when<dynamic>(
      () => builder.then<dynamic>(any(), onError: any(named: 'onError')),
    ).thenAnswer((inv) {
      final onValue = inv.positionalArguments[0] as dynamic Function(dynamic);
      return Future<dynamic>.value(value).then(onValue);
    });
  }

  void stubRpcThrows(Object error) {
    when(
      () => mockClient.rpc(
        'evaluate_feature_flags',
        params: any(named: 'params'),
      ),
    ).thenThrow(error);
  }

  setUp(() {
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    builder = MockRpcBuilder();
    when(() => mockClient.auth).thenReturn(mockAuth);
    repository = FeatureFlagRemoteDataSource(client: mockClient);
  });

  group('evaluate', () {
    test('sends every registry key and parses a well-formed response', () async {
      stubRpc([
        {'key': 'player_direct_player', 'enabled': true, 'version': 7},
      ]);

      final evaluations = await repository.evaluate(FeatureFlagKey.all);

      expect(evaluations, hasLength(1));
      expect(evaluations.single.key, FeatureFlagKey.playerDirectPlayer);
      expect(evaluations.single.enabled, isTrue);
      expect(evaluations.single.version, 7);
      expect(evaluations.single.isRegistered, isTrue);

      final captured = verify(
        () => mockClient.rpc(
          'evaluate_feature_flags',
          params: captureAny(named: 'params'),
        ),
      ).captured.single as Map<String, dynamic>;

      expect(captured['p_keys'], [
        for (final key in FeatureFlagKey.all) key.serverKey,
      ]);
    });

    test('skips rows for keys the current build does not know', () async {
      // Registered server-side for a NEWER app version — this build has no
      // behavior attached, so it must be dropped, not surfaced as a value.
      stubRpc([
        {'key': 'future.feature', 'enabled': true, 'version': 2},
        {'key': 'player_direct_player', 'enabled': false, 'version': 1},
      ]);

      final evaluations = await repository.evaluate(FeatureFlagKey.all);

      expect(evaluations, hasLength(1));
      expect(evaluations.single.key, FeatureFlagKey.playerDirectPlayer);
    });

    test('skips malformed rows instead of failing the batch', () async {
      stubRpc([
        {'key': 'player_direct_player', 'enabled': true, 'version': 1},
        {'key': 42, 'enabled': true, 'version': 1}, // bad key type
        {'key': 'player_direct_player', 'enabled': 'yes'}, // bad enabled type
        'not-a-map',
        null,
      ]);

      final evaluations = await repository.evaluate(FeatureFlagKey.all);

      expect(evaluations, hasLength(1));
      expect(evaluations.single.version, 1);
    });

    test('treats a non-list response as an empty result', () async {
      stubRpc('unexpected');
      expect(await repository.evaluate(FeatureFlagKey.all), isEmpty);
    });

    test('empty key list short-circuits without touching the RPC', () async {
      final evaluations = await repository.evaluate(const []);

      expect(evaluations, isEmpty);
      verifyNever(
        () => mockClient.rpc(any(), params: any(named: 'params')),
      );
    });

    test('maps PostgrestException to a typed ServerException', () async {
      stubRpcThrows(const PostgrestException(message: 'denied', code: '42501'));

      await expectLater(
        repository.evaluate(FeatureFlagKey.all),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            '42501',
          ),
        ),
      );
    });

    test('maps a non-retryable server failure without retrying', () async {
      // RLS/permission denials are business errors — NetworkGuard must not
      // burn retry attempts on them.
      stubRpcThrows(const PostgrestException(message: 'denied', code: '42501'));

      await expectLater(
        repository.evaluate(FeatureFlagKey.all),
        throwsA(isA<ServerException>()),
      );
      verify(
        () => mockClient.rpc(
          'evaluate_feature_flags',
          params: any(named: 'params'),
        ),
      ).called(1);
    });

    test('maps a socket-level failure to NoInternetException (with retries)',
        () async {
      // Connectivity-level failures ARE retried by NetworkGuard; the final
      // error surfaces as the mapped typed exception.
      stubRpcThrows(Exception('SocketException: failed host lookup'));

      await expectLater(
        repository.evaluate(FeatureFlagKey.all),
        throwsA(isA<NoInternetException>()),
      );
    });

    test('maps a stalled response to RequestTimeoutException', () async {
      // NetworkGuard applies its own .timeout to the awaited call; a
      // TimeoutException escaping the call is classified by the mapper.
      when(
        () => mockClient.rpc(
          'evaluate_feature_flags',
          params: any(named: 'params'),
        ),
      ).thenThrow(TimeoutException('stalled'));

      await expectLater(
        repository.evaluate(FeatureFlagKey.all),
        throwsA(isA<RequestTimeoutException>()),
      );
    });
  });

  group('currentUserId', () {
    test('returns the signed-in user id', () {
      when(() => mockAuth.currentUser).thenReturn(
        const User(
          id: 'user-1',
          aud: 'authenticated',
          appMetadata: {},
          userMetadata: {},
          createdAt: '2026-09-13T00:00:00Z',
        ),
      );

      expect(repository.currentUserId, 'user-1');
    });

    test('returns null when signed out', () {
      when(() => mockAuth.currentUser).thenReturn(null);
      expect(repository.currentUserId, isNull);
    });
  });
}
