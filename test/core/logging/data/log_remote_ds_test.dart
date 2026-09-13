import 'dart:async';

import 'package:app/core/logging/data/log_remote_ds.dart';
import 'package:app/core/logging/domain/app_event.dart';
import 'package:app/core/logging/domain/event_metadata.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

/// `SupabaseClient.rpc()` returns `PostgrestFilterBuilder<dynamic>`, not a
/// plain Future — it only behaves like one when awaited. See
/// test/features/auth/application/services/check_student_app_access_service_test.dart
/// for the full rationale; this Fake wraps a resolved value. `timeout` must
/// be overridden explicitly: PostgrestFilterBuilder implements Future by
/// defining `then` only, so `Future`-level members fall through to
/// noSuchMethod otherwise.
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

LogEntry _entry({String type = 'lesson_started'}) => LogEntry(
      idempotencyKey: 'k-$type',
      eventType: type,
      category: EventCategory.video.name,
      userId: 'user-1',
      details: const {'lesson_id': 'l-1'},
      createdAt: DateTime(2026),
    );

void main() {
  late MockSupabaseClient client;
  late LogRemoteDataSource dataSource;

  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    client = MockSupabaseClient();
    dataSource = LogRemoteDataSource(client);
  });

  group('LogRemoteDataSource.syncBatch', () {
    test('returns true immediately for an empty batch without RPC', () async {
      final result = await dataSource.syncBatch([]);
      expect(result, isTrue);
      verifyNever(
        () => client.rpc('log_activity_async', params: any(named: 'params')),
      );
    });

    test('submits each entry and returns true when accepted', () async {
      when(() => client.rpc('log_activity_async', params: any(named: 'params')))
          .thenAnswer(
        (_) => _FakePostgrestFilterBuilder<dynamic>(null),
      );

      final result = await dataSource.syncBatch([_entry(), _entry()]);

      expect(result, isTrue);
      verify(
        () => client.rpc('log_activity_async', params: any(named: 'params')),
      ).called(2);
    });

    test('returns false (no throw) when the RPC fails', () async {
      when(() => client.rpc('log_activity_async', params: any(named: 'params')))
          .thenAnswer(
        (_) => _ThrowingPostgrestFilterBuilder<dynamic>(
          const PostgrestException(code: '42501', message: 'denied'),
        ),
      );

      final result = await dataSource.syncBatch([_entry()]);

      expect(result, isFalse);
    });

    test('returns false when the RPC never resolves before timeout', () async {
      when(() => client.rpc('log_activity_async', params: any(named: 'params')))
          .thenAnswer(
        (_) => _ThrowingPostgrestFilterBuilder<dynamic>(
          TimeoutException('telemetry timeout'),
        ),
      );

      final result = await dataSource.syncBatch([_entry()]);

      expect(result, isFalse);
    });
  });

  group('LogRemoteDataSource.logLessonStarted', () {
    test('submits the lesson_started payload with player metadata',
        () async {
      Map<String, Object?>? captured;
      when(() => client.rpc('log_activity_async', params: any(named: 'params')))
          .thenAnswer((invocation) {
        captured = invocation.namedArguments[#params] as Map<String, Object?>?;
        return _FakePostgrestFilterBuilder<dynamic>(null);
      });

      final result = await dataSource.logLessonStarted(
        userId: 'user-1',
        courseId: 'course-1',
        lessonId: 'lesson-1',
        player: 'player4',
        devicePlatform: 'android',
      );

      expect(result, isTrue);
      expect(captured, isNotNull);
      expect(captured!['p_user_id'], 'user-1');
      expect(captured!['p_type'], 'lesson_started');
      expect(captured!['p_risk_level'], 'low');
      final details = captured!['p_details'] as Map<String, dynamic>;
      expect(details['course_id'], 'course-1');
      expect(details['lesson_id'], 'lesson-1');
      expect(details['player'], 'player4');
      expect(details['device_platform'], 'android');
    });

    test('swallows RPC failures and returns false (never throws)',
        () async {
      when(() => client.rpc('log_activity_async', params: any(named: 'params')))
          .thenAnswer(
        (_) => _ThrowingPostgrestFilterBuilder<dynamic>(
          StateError('socket closed'),
        ),
      );

      final result = await dataSource.logLessonStarted(
        userId: 'user-1',
        courseId: 'course-1',
        lessonId: 'lesson-1',
        player: 'youtube',
        devicePlatform: 'ios',
      );

      expect(result, isFalse);
    });
  });
}
