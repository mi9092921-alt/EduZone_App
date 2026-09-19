import 'dart:async';
import 'dart:convert';

import 'package:app/core/error/exceptions.dart';
import 'package:app/features/home/data/datasources/home_remote_datasource_impl.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/fake_supabase_http_client.dart';

/// Contract tests for [HomeRemoteDataSourceImpl].
///
/// A real [SupabaseClient] is constructed over a [FakeHttpClient] so the
/// actual PostgREST request/response machinery runs offline (same pattern
/// as `notifications_remote_ds_test.dart`). Authenticated paths establish
/// an in-memory session via `auth.setSession`, whose `/auth/v1/user`
/// lookup the fake HTTP client serves.
void main() {
  const tUserId = 'user-1';
  const tTenantId = 'tenant-1';

  final tProgressRowCourse1 = {
    'lesson_id': 'lesson-1',
    'completed': false,
    'progress_pct': 40.0,
    'last_watched': '2026-09-10T10:00:00.000Z',
    'course': {'id': 'course-1', 'title': 'Course One', 'thumbnail_url': null},
    'lesson': {
      'id': 'lesson-1',
      'title': 'Lesson One',
      'section_id': 'section-1',
      'section': {'title': 'Section A'},
    },
  };

  final tProgressRowCourse2 = {
    'lesson_id': 'lesson-2',
    'completed': false,
    'progress_pct': 10.0,
    'last_watched': '2026-09-11T10:00:00.000Z',
    'course': {'id': 'course-2', 'title': 'Course Two', 'thumbnail_url': null},
    'lesson': {
      'id': 'lesson-2',
      'title': 'Lesson Two',
      'section_id': 'section-2',
      'section': {'title': 'Section B'},
    },
  };

  /// Builds an unsigned (signature isn't checked client-side) JWT with a
  /// far-future expiry, as `GoTrueClient.setSession` expects.
  String buildJwt() {
    String encode(Map<String, dynamic> m) =>
        base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
    return '${encode({'alg': 'none', 'typ': 'JWT'})}.'
        '${encode({'sub': tUserId, 'iat': 1000000000, 'exp': 9999999999})}.';
  }

  /// A client whose auth session is established against the fake HTTP
  /// layer; `appMetadata.tenant_id` matches what the real JWT carries.
  Future<SupabaseClient> buildSignedInClient(
    FutureOr<http.Response> Function(http.BaseRequest request) handler,
  ) async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: FakeHttpClient((request) {
        if (request.url.path.endsWith('/auth/v1/user')) {
          return http.Response(
            jsonEncode({
              'id': tUserId,
              'aud': 'authenticated',
              'email': 'student@example.com',
              'app_metadata': {'tenant_id': tTenantId},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return handler(request);
      }),
    );
    await client.auth.setSession('refresh-token', accessToken: buildJwt());
    return client;
  }

  group('getResumeLessons', () {
    test('returns [] for an unauthenticated session without querying',
        () async {
      var queried = false;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        httpClient: FakeHttpClient((_) async {
          queried = true;
          return http.Response('[]', 200);
        }),
      );
      final dataSource = HomeRemoteDataSourceImpl(client: client);

      expect(await dataSource.getResumeLessons(), isEmpty);
      expect(queried, isFalse);
    });

    test('returns [] when the user has no active enrollments', () async {
      final client = await buildSignedInClient(
        (_) async => http.Response(
          jsonEncode([]),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      final dataSource = HomeRemoteDataSourceImpl(client: client);

      expect(await dataSource.getResumeLessons(), isEmpty);
    });

    test('maps the embedded progress rows and keeps only the newest row '
        'per course', () async {
      // Two rows for course-1 (deduplicated to the first/newest) plus one
      // for course-2.
      final client = await buildSignedInClient((request) async {
        if (request.url.path.endsWith('/rest/v1/enrollments')) {
          return http.Response(
            jsonEncode([
              {'course_id': 'course-1'},
              {'course_id': 'course-2'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/rest/v1/user_progress')) {
          return http.Response(
            jsonEncode([
              tProgressRowCourse1,
              {
                ...tProgressRowCourse1,
                'lesson_id': 'lesson-1b',
                'progress_pct': 90.0,
              },
              tProgressRowCourse2,
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('[]', 200);
      });
      final dataSource = HomeRemoteDataSourceImpl(client: client);

      final lessons = await dataSource.getResumeLessons();

      expect(lessons, hasLength(2));
      expect(lessons[0].courseId, 'course-1');
      expect(lessons[0].lessonId, 'lesson-1');
      expect(lessons[0].lessonTitle, 'Lesson One');
      expect(lessons[0].courseTitle, 'Course One');
      expect(lessons[0].sectionTitle, 'Section A');
      expect(lessons[0].progressPct, 40.0);
      // The 90% duplicate for course-1 must not have been picked up —
      // only one resume entry per course.
      expect(lessons.map((l) => l.courseId), ['course-1', 'course-2']);
    });

    test('caps the result at 3 lessons', () async {
      final client = await buildSignedInClient((request) async {
        if (request.url.path.endsWith('/rest/v1/enrollments')) {
          return http.Response(
            jsonEncode([
              {'course_id': 'course-1'},
              {'course_id': 'course-2'},
              {'course_id': 'course-3'},
              {'course_id': 'course-4'},
              {'course_id': 'course-5'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/rest/v1/user_progress')) {
          return http.Response(
            jsonEncode([
              for (var i = 1; i <= 5; i++)
                {
                  'lesson_id': 'lesson-$i',
                  'completed': false,
                  'progress_pct': 5.0 * i,
                  'last_watched': '2026-09-10T10:0$i:00.000Z',
                  'course': {
                    'id': 'course-$i',
                    'title': 'Course $i',
                    'thumbnail_url': null,
                  },
                  'lesson': {
                    'id': 'lesson-$i',
                    'title': 'Lesson $i',
                    'section_id': 'section-$i',
                    'section': {'title': 'Section $i'},
                  },
                },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('[]', 200);
      });
      final dataSource = HomeRemoteDataSourceImpl(client: client);

      expect(await dataSource.getResumeLessons(), hasLength(3));
    });
  });

  group('getResumeLesson', () {
    test('maps the single embedded row to a ResumeLesson', () async {
      final client = await buildSignedInClient((request) async {
        if (request.url.path.endsWith('/rest/v1/user_progress')) {
          return http.Response(
            jsonEncode(tProgressRowCourse1),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('[]', 200);
      });
      final dataSource = HomeRemoteDataSourceImpl(client: client);

      final lesson = await dataSource.getResumeLesson();

      expect(lesson, isNotNull);
      expect(lesson!.courseId, 'course-1');
      expect(lesson.progressPct, 40.0);
      expect(
        lesson.lastWatched,
        DateTime.parse('2026-09-10T10:00:00.000Z'),
      );
    });

    test('returns null when no in-progress row exists', () async {
      final client = await buildSignedInClient(
        (_) async => http.Response(
          jsonEncode(null),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      final dataSource = HomeRemoteDataSourceImpl(client: client);

      expect(await dataSource.getResumeLesson(), isNull);
    });

    test('degrades to null on any failure instead of throwing', () async {
      final client = await buildSignedInClient(
        (_) async => http.Response(
          jsonEncode({'message': 'boom', 'code': 'XX999'}),
          500,
          headers: {'content-type': 'application/json'},
        ),
      );
      final dataSource = HomeRemoteDataSourceImpl(client: client);

      expect(await dataSource.getResumeLesson(), isNull);
    });
  });

  group('getRecentCourses', () {
    test('maps the enrollment-embedded course rows and backfills the '
        'tenant and progress fields', () async {
      final client = await buildSignedInClient((request) async {
        if (request.url.path.endsWith('/rest/v1/enrollments')) {
          return http.Response(
            jsonEncode([
              {
                'progress_pct': 50.0,
                'completed_lessons': 3,
                'total_lessons': 10,
                'course': {
                  'id': 'course-1',
                  'title': 'Course One',
                  'tenant_id': null,
                  'status': null,
                },
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('[]', 200);
      });
      final dataSource = HomeRemoteDataSourceImpl(client: client);

      final courses = await dataSource.getRecentCourses();

      expect(courses, hasLength(1));
      expect(courses.single.id, 'course-1');
      expect(courses.single.title, 'Course One');
      expect(courses.single.tenantId, tTenantId);
      expect(courses.single.status, 'published');
      expect(courses.single.progressPct, 50.0);
      expect(courses.single.completedLessons, 3);
      expect(courses.single.totalLessons, 10);
    });

    test('returns [] for an unauthenticated session without querying',
        () async {
      var queried = false;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        httpClient: FakeHttpClient((_) async {
          queried = true;
          return http.Response('[]', 200);
        }),
      );
      final dataSource = HomeRemoteDataSourceImpl(client: client);

      expect(await dataSource.getRecentCourses(), isEmpty);
      expect(queried, isFalse);
    });

    test('rethrows a PostgrestException as a ServerException preserving the '
        'Postgres code', () async {
      final client = await buildSignedInClient(
        (_) async => http.Response(
          jsonEncode({'message': 'rls recursion', 'code': '42P17'}),
          400,
          headers: {'content-type': 'application/json'},
        ),
      );
      final dataSource = HomeRemoteDataSourceImpl(client: client);

      await expectLater(
        () => dataSource.getRecentCourses(),
        throwsA(
          isA<ServerException>()
              .having((e) => e.message, 'message', 'rls recursion')
              .having((e) => e.code, 'code', '42P17'),
        ),
      );
    });
  });

  group('getRecentTodos', () {
    test('returns at most 3 open, non-deleted todos', () async {
      final client = await buildSignedInClient((request) async {
        if (request.url.path.endsWith('/rest/v1/todos')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'todo-1',
                'user_id': tUserId,
                'tenant_id': tTenantId,
                'title': 'Study math',
                'is_completed': false,
                'priority': 0,
                'deleted_at': null,
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('[]', 200);
      });
      final dataSource = HomeRemoteDataSourceImpl(client: client);

      final todos = await dataSource.getRecentTodos();

      expect(todos, hasLength(1));
      expect(todos.single.id, 'todo-1');
      expect(todos.single.title, 'Study math');
      expect(todos.single.isCompleted, isFalse);
    });

    test('returns [] for an unauthenticated session', () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        httpClient: FakeHttpClient((_) async => http.Response('[]', 200)),
      );
      final dataSource = HomeRemoteDataSourceImpl(client: client);

      expect(await dataSource.getRecentTodos(), isEmpty);
    });
  });
}
