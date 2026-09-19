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

/// Contract tests for [VideoPlayerRemoteDataSource] (progress upsert +
/// activity logging) over a real [SupabaseClient] wired to a
/// [FakeHttpClient], so the actual PostgREST machinery runs offline.
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

    test('upserts on the (user_id, course_id, lesson_id) conflict target '
        'with the tenant resolved from the JWT metadata', () async {
      http.Request? captured;
      final dataSource = await buildSignedInDataSource((request) async {
        captured = request as http.Request;
        return http.Response('', 201);
      });

      await dataSource.syncProgressBatch(const [tSyncItem]);

      expect(captured!.method, 'POST');
      expect(captured!.url.path, endsWith('/rest/v1/user_progress'));
      expect(
        captured!.url.queryParameters['on_conflict'],
        'user_id,course_id,lesson_id',
      );
      final body = jsonDecode(captured!.body) as List<dynamic>;
      final row = body.single as Map<String, dynamic>;
      expect(row['user_id'], 'user-1');
      expect(row['course_id'], 'course-1');
      expect(row['lesson_id'], 'lesson-1');
      expect(row['tenant_id'], 'tenant-1');
      expect(row['completed'], true);
      expect(row['progress_pct'], 100);
      expect(row['watch_time_sec'], 42);
      // A completed row carries completed_at; both timestamps are ISO
      // UTC strings.
      expect(row['completed_at'], isNotNull);
      expect((row['last_watched'] as String), endsWith('Z'));
    });

    test('omits completed_at/watch_time_sec for an in-progress, unwatched '
        'row', () async {
      http.Request? captured;
      final dataSource = await buildSignedInDataSource((request) async {
        captured = request as http.Request;
        return http.Response('', 201);
      });

      await dataSource.syncProgress(
        courseId: 'course-1',
        lessonId: 'lesson-2',
        completed: false,
        progressPct: 35.5,
      );

      final row =
          (jsonDecode(captured!.body) as List<dynamic>).single
              as Map<String, dynamic>;
      expect(row['completed'], false);
      expect(row.containsKey('completed_at'), isFalse);
      expect(row.containsKey('watch_time_sec'), isFalse);
    });

    test('falls back to the courses table for the tenant when the JWT '
        'carries no tenant metadata', () async {
      final requests = <http.Request>[];
      final dataSource = await buildSignedInDataSource(
        (request) async {
          requests.add(request as http.Request);
          if (request.url.path.endsWith('/rest/v1/courses')) {
            return http.Response(
              jsonEncode({'tenant_id': 'tenant-from-db'}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('', 201);
        },
        appMetadata: null, // no tenant in JWT metadata
      );

      await dataSource.syncProgressBatch(const [tSyncItem]);

      expect(requests.first.url.path, endsWith('/rest/v1/courses'));
      expect(requests.first.url.queryParameters['id'], 'eq.course-1');
      final upsertRow =
          (jsonDecode(requests.last.body) as List<dynamic>).single
              as Map<String, dynamic>;
      expect(upsertRow['tenant_id'], 'tenant-from-db');
    });

    test('fails with a clear ServerException when the tenant cannot be '
        'determined at all', () async {
      final dataSource = await buildSignedInDataSource(
        (request) async {
          if (request.url.path.endsWith('/rest/v1/courses')) {
            // single() with zero rows → PostgREST 406-style empty result;
            // the DB row itself carries a NULL tenant.
            return http.Response(
              jsonEncode({'tenant_id': null}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('', 201);
        },
        appMetadata: null,
      );

      await expectLater(
        () => dataSource.syncProgressBatch(const [tSyncItem]),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('Could not determine tenant_id'),
          ),
        ),
      );
    });

    test('surfaces a PostgrestException on the upsert as a ServerException',
        () async {
      final dataSource = await buildSignedInDataSource(
        (_) async => http.Response(
          jsonEncode({'message': 'new row violates RLS policy', 'code': '42501'}),
          400,
          headers: {'content-type': 'application/json'},
        ),
      );

      await expectLater(
        () => dataSource.syncProgressBatch(const [tSyncItem]),
        throwsA(
          isA<ServerException>()
              .having(
                (e) => e.message,
                'message',
                'new row violates RLS policy',
              )
              .having((e) => e.code, 'code', '42501'),
        ),
      );
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
