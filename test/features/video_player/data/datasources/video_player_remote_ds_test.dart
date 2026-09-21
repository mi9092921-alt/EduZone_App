import 'dart:async';
import 'dart:convert';

import 'package:app/core/error/exceptions.dart';
import 'package:app/features/video_player/data/datasources/video_player_remote_ds.dart';
import 'package:app/features/video_player/domain/entities/lesson_progress_sync_item.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/fake_supabase_http_client.dart';

/// Contract tests for [VideoPlayerRemoteDataSource] (progress sync via the
/// `update_lesson_progress` RPC + activity logging) over a real
/// [SupabaseClient] wired to a [FakeHttpClient], so the actual PostgREST
/// machinery runs offline.
void main() {
  const tSyncItem = LessonProgressSyncItem(
    courseId: 'course-1',
    lessonId: 'lesson-1',
    completed: true,
    progressPct: 100,
    watchTimeSec: 42,
  );

  VideoPlayerRemoteDataSource buildDataSource(
    FutureOr<http.Response> Function(http.BaseRequest request) handler,
  ) {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: FakeHttpClient(handler),
    );
    return VideoPlayerRemoteDataSource(client);
  }

  String buildJwt() {
    String encode(Map<String, dynamic> m) =>
        base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
    return '${encode({'alg': 'none', 'typ': 'JWT'})}.'
        '${encode({'sub': 'user-1', 'iat': 1000000000, 'exp': 9999999999})}.';
  }

  /// Client with an in-memory session; the signed-in user carries
  /// [appMetadata] (defaults to the real JWT's tenant metadata).
  Future<VideoPlayerRemoteDataSource> buildSignedInDataSource(
    FutureOr<http.Response> Function(http.BaseRequest request) handler, {
    Map<String, dynamic>? appMetadata = const {'tenant_id': 'tenant-1'},
  }) async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: FakeHttpClient((request) {
        if (request.url.path.endsWith('/auth/v1/user')) {
          return http.Response(
            jsonEncode({
              'id': 'user-1',
              'aud': 'authenticated',
              'email': 'student@example.com',
              'app_metadata': ?appMetadata,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return handler(request);
      }),
    );
    await client.auth.setSession('refresh-token', accessToken: buildJwt());
    return VideoPlayerRemoteDataSource(client);
  }

  group('syncProgressBatch', () {
    test('is a no-op for an empty batch without issuing a request', () async {
      var queried = false;
      final dataSource = buildDataSource((_) async {
        queried = true;
        return http.Response('', 204);
      });

      await dataSource.syncProgressBatch(const []);

      expect(queried, isFalse);
    });

    test('fails closed with ServerException for an unauthenticated session',
        () async {
      var queried = false;
      final dataSource = buildDataSource((_) async {
        queried = true;
        return http.Response('', 204);
      });

      await expectLater(
        () => dataSource.syncProgressBatch(const [tSyncItem]),
        throwsA(
          isA<ServerException>()
              .having((e) => e.message, 'message', 'User not authenticated'),
        ),
      );
      expect(queried, isFalse);
    });

    test('delegates each item to the update_lesson_progress RPC — the '
        'server-authoritative path that validates entitlement, derives the '
        'tenant, and writes the row', () async {
      final requests = <http.Request>[];
      final dataSource = await buildSignedInDataSource((request) async {
        requests.add(request as http.Request);
        return http.Response('', 204);
      });

      await dataSource.syncProgressBatch(const [tSyncItem]);

      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(
        requests.single.url.path,
        endsWith('/rest/v1/rpc/update_lesson_progress'),
      );
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body, {
        'p_course_id': 'course-1',
        'p_lesson_id': 'lesson-1',
        'p_progress_pct': 100,
        'p_completed': true,
        'p_watch_time_sec': 42,
      });
      // The RPC derives identity and tenant server-side — the client must
      // NOT send either (the previous direct user_progress upsert used to).
      expect(body.containsKey('tenant_id'), isFalse);
      expect(body.containsKey('user_id'), isFalse);
    });

    test('issues one RPC per item with each item’s values verbatim',
        () async {
      final bodies = <Map<String, dynamic>>[];
      final dataSource = await buildSignedInDataSource((request) async {
        bodies.add(
          jsonDecode((request as http.Request).body) as Map<String, dynamic>,
        );
        return http.Response('', 204);
      });

      await dataSource.syncProgressBatch(const [
        tSyncItem,
        LessonProgressSyncItem(
          courseId: 'course-2',
          lessonId: 'lesson-2',
          completed: false,
          progressPct: 35.5,
        ),
      ]);

      expect(bodies, hasLength(2));
      expect(bodies[0]['p_lesson_id'], 'lesson-1');
      expect(bodies[0]['p_watch_time_sec'], 42);
      expect(bodies[1]['p_lesson_id'], 'lesson-2');
      expect(bodies[1]['p_completed'], false);
      expect(bodies[1]['p_progress_pct'], 35.5);
      expect(bodies[1].containsKey('p_watch_time_sec'), isFalse);
    });

    test('surfaces a PostgrestException (e.g. RPC entitlement denial) as a '
        'ServerException carrying the message and code', () async {
      final dataSource = await buildSignedInDataSource(
        (_) async => http.Response(
          jsonEncode({'message': 'LESSON_ACCESS_DENIED', 'code': 'P0001'}),
          400,
          headers: {'content-type': 'application/json'},
        ),
      );

      await expectLater(
        () => dataSource.syncProgressBatch(const [tSyncItem]),
        throwsA(
          isA<ServerException>()
              .having((e) => e.message, 'message', 'LESSON_ACCESS_DENIED')
              .having((e) => e.code, 'code', 'P0001'),
        ),
      );
    });

    test('still attempts the remaining items when one fails, then rethrows '
        'the first failure (the sync engine re-queues the batch; writes are '
        'idempotent)', () async {
      var calls = 0;
      final dataSource = await buildSignedInDataSource((request) async {
        calls++;
        if (calls == 1) return http.Response('', 204);
        return http.Response(
          jsonEncode({'message': 'boom', 'code': 'XX000'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      await expectLater(
        () => dataSource.syncProgressBatch(const [tSyncItem, tSyncItem]),
        throwsA(isA<ServerException>()),
      );
      expect(calls, 2);
    });
  });

  group('logActivity', () {
    test('calls log_activity_async with the session user and metadata',
        () async {
      http.Request? captured;
      final dataSource = await buildSignedInDataSource((request) async {
        captured = request as http.Request;
        return http.Response('null', 200);
      });

      await dataSource.logActivity(
        eventType: 'video_heartbeat',
        metadata: {'lesson_id': 'lesson-1', 'position_sec': 30},
      );

      expect(captured, isNotNull);
      expect(captured!.url.path, endsWith('/rpc/log_activity_async'));
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['p_user_id'], 'user-1');
      expect(body['p_type'], 'video_heartbeat');
      expect(body['p_details'], {'lesson_id': 'lesson-1', 'position_sec': 30});
    });

    test('is skipped entirely for an unauthenticated session', () async {
      var queried = false;
      final dataSource = buildDataSource((_) async {
        queried = true;
        return http.Response('null', 200);
      });

      await dataSource.logActivity(eventType: 'video_heartbeat', metadata: {});

      expect(queried, isFalse);
    });

    test('never throws — telemetry failures are swallowed by contract',
        () async {
      final dataSource = await buildSignedInDataSource(
        (_) async => http.Response(
          jsonEncode({'message': 'rpc missing', 'code': 'PGRST202'}),
          404,
          headers: {'content-type': 'application/json'},
        ),
      );

      // Must complete without throwing.
      await dataSource.logActivity(eventType: 'video_heartbeat', metadata: {});
    });
  });
}
