import 'dart:async';

import 'package:app/core/security/data/security_incident_remote_ds.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

/// `SupabaseClient.rpc()` returns `PostgrestFilterBuilder<dynamic>`, not a
/// plain Future — it only behaves like one when awaited. See
/// test/core/logging/data/log_remote_ds_test.dart for the full rationale;
/// this Fake wraps a resolved value. `timeout` must be overridden
/// explicitly: PostgrestFilterBuilder implements Future by defining `then`
/// only, so `Future`-level members fall through to noSuchMethod otherwise.
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

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) {
    return Future<T>.value(_value).timeout(timeLimit, onTimeout: onTimeout);
  }
}

class _ThrowingPostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  _ThrowingPostgrestFilterBuilder(this._error);
  final Object _error;

  @override
  Future<S> then<S>(
    FutureOr<S> Function(T value) onValue, {
    Function? onError,
  }) {
    return Future<T>.error(_error).then(onValue, onError: onError);
  }

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) {
    return Future<T>.error(_error).timeout(timeLimit, onTimeout: onTimeout);
  }
}

void main() {
  late MockSupabaseClient client;
  late SecurityIncidentRemoteDs ds;
  late Map<String, Object?>? capturedParams;

  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    client = MockSupabaseClient();
    capturedParams = null;
    when(() => client.rpc(
          'report_security_incident',
          params: any(named: 'params'),
        )).thenAnswer((invocation) {
      capturedParams = invocation.namedArguments[#params] as Map<String, Object?>?;
      return _FakePostgrestFilterBuilder<dynamic>(null);
    });
    // Deliberately NO stub for client.auth: the datasource must never need a
    // session — the RPC accepts pre-auth callers (anon, user_id NULL), and
    // this suite proves that by letting any accidental auth access throw a
    // mocktail missing-stub error.
    ds = SecurityIncidentRemoteDs(client);
  });

  group('SecurityIncidentRemoteDs.reportIncident', () {
    test('submits every field through the RPC params', () async {
      await ds.reportIncident(
        threat: 'App Integrity Compromised',
        platform: 'android',
        platformVersion: '14',
        isReleaseBuild: true,
        deviceFingerprint: 'fp-sha256',
        appVersion: '1.2.0',
        appBuildNumber: '42',
        details: {'step': 'freerasp'},
      );

      expect(capturedParams, isNotNull);
      expect(capturedParams!['p_threat'], 'App Integrity Compromised');
      expect(capturedParams!['p_platform'], 'android');
      expect(capturedParams!['p_platform_version'], '14');
      expect(capturedParams!['p_is_release_build'], isTrue);
      expect(capturedParams!['p_device_fingerprint'], 'fp-sha256');
      expect(capturedParams!['p_app_version'], '1.2.0');
      expect(capturedParams!['p_app_build_number'], '42');
      expect(capturedParams!['p_details'], {'step': 'freerasp'});
      // detected_at is stamped server-side; the client never sends a clock.
      expect(capturedParams!.containsKey('detected_at'), isFalse);
      expect(capturedParams!.containsKey('p_detected_at'), isFalse);
    });

    test('omittable fields arrive as null, not missing', () async {
      await ds.reportIncident(threat: 'Hooks Detected', platform: 'ios');

      expect(capturedParams!['p_platform_version'], isNull);
      expect(capturedParams!['p_device_fingerprint'], isNull);
      expect(capturedParams!['p_details'], isNull);
      expect(capturedParams!['p_is_release_build'], isFalse);
    });

    test('propagates a PostgrestException (caller buffers — contract)',
        () async {
      when(() => client.rpc(
            'report_security_incident',
            params: any(named: 'params'),
          )).thenAnswer(
        (_) => _ThrowingPostgrestFilterBuilder<dynamic>(
          const PostgrestException(code: 'P0001', message: 'INVALID_INCIDENT_THREAT'),
        ),
      );

      await expectLater(
        ds.reportIncident(threat: '', platform: 'android'),
        throwsA(isA<PostgrestException>()),
      );
    });
  });
}
