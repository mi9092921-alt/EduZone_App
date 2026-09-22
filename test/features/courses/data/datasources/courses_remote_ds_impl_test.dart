import 'dart:async';
import 'dart:convert';

import 'package:app/core/error/exceptions.dart';
import 'package:app/features/courses/data/datasources/courses_remote_ds_impl.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/fake_supabase_http_client.dart';

/// Contract tests for [CoursesRemoteDataSourceImpl].
///
/// This datasource reaches Supabase through the static
/// `SupabaseService.client` (no injected client), so the file
/// `Supabase.initialize(...)`s once with a [FakeHttpClient] and then drives
/// the REAL PostgREST request/response machinery entirely offline. This is
/// what makes the exact `PostgrestException → ServerException →
/// NetworkGuard → SessionRevokedException` chain observable end-to-end.
void main() {
  const tCourseRow = {
    'id': 'course-1',
    'tenant_id': 'tenant-1',
    'title': 'Flutter Mastery',
    'status': 'published',
    'is_discoverable': true,
    'teacher': {
      'first_name': 'Ada',
      'last_name': 'Lovelace',
      'avatar_url': 'https://example.com/ada.png',
    },
  };

  final tEnrollmentRow = {
    'id': 'enr-1',
    'user_id': 'user-1',
    'course_id': 'course-1',
    'tenant_id': 'tenant-1',
    'status': 'active',
    'course': tCourseRow,
  };

  late CoursesRemoteDataSourceImpl dataSource;
  FutureOr<http.Response> Function(http.BaseRequest request) handler =
      (_) => http.Response(
            jsonEncode({'message': 'unexpected request', 'code': 'TEST404'}),
            404,
            headers: {'content-type': 'application/json'},
          );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Supabase.initialize wires a SharedPreferences-backed PKCE async
    // storage whose eager initialization must not hit a missing plugin
    // channel — mock it before initialize.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://fake-project.supabase.co',
      publishableKey: 'test-anon-key',
      httpClient: FakeHttpClient((request) => handler(request)),
      // In-memory session only: the singleton starts signed-out so the
      // unauthenticated group runs deterministically before the
      // authenticated one signs in.
      authOptions: const FlutterAuthClientOptions(persistSession: false),
    );
    dataSource = CoursesRemoteDataSourceImpl();
  });

  String buildJwt() {
    String encode(Map<String, dynamic> m) =>
        base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
    return '${encode({'alg': 'none', 'typ': 'JWT'})}.'
        '${encode({'sub': 'user-1', 'iat': 1000000000, 'exp': 9999999999})}.';
  }

  /// Establishes the in-memory authenticated session the datasource reads
  /// via `SupabaseService.client.auth.currentUser`. The `/auth/v1/user`
  /// lookup setSession performs is served with a tenant-carrying user,
  /// matching the real JWT's `app_metadata`.
  Future<void> signIn() async {
    final previousHandler = handler;
    handler = (request) {
      if (request.url.path.endsWith('/auth/v1/user')) {
        return http.Response(
          jsonEncode({
            'id': 'user-1',
            'aud': 'authenticated',
            'email': 'student@example.com',
            'app_metadata': {'tenant_id': 'tenant-1'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return previousHandler(request);
    };
    await Supabase.instance.client.auth.setSession(
      'refresh-token',
      accessToken: buildJwt(),
    );
  }

  /// PostgREST-shaped error response helper.
  http.Response postgrestError(String message, String code) => http.Response(
        jsonEncode({'message': message, 'code': code}),
        400,
        headers: {'content-type': 'application/json'},
      );

  group('unauthenticated session', () {
    test('getMyCourses fails closed with ServerException("User not '
        'authenticated") without issuing a request', () async {
      var queried = false;
      handler = (_) async {
        queried = true;
        return http.Response('[]', 200);
      };

      await expectLater(
        () => dataSource.getMyCourses(),
        throwsA(
          isA<ServerException>()
              .having((e) => e.message, 'message', 'User not authenticated'),
        ),
      );
      expect(queried, isFalse);
    });

    test('updateLessonProgress fails closed without issuing a request',
        () async {
      var queried = false;
      handler = (_) async {
        queried = true;
        return http.Response('', 204);
      };

      await expectLater(
        () => dataSource.updateLessonProgress(
          courseId: 'course-1',
          lessonId: 'lesson-1',
          completed: true,
          progressPct: 100,
        ),
        throwsA(isA<ServerException>()),
      );
      expect(queried, isFalse);
    });

    test('getUserSubscribedCourseIds degrades to an empty set', () async {
      // Deliberate degradation contract: a failed/unavailable subscribed
      // set must never fail a screen, only render courses as "not
      // subscribed".
      expect(await dataSource.getUserSubscribedCourseIds(), isEmpty);
    });

    test('getCoursesByIds short-circuits to [] for an empty id list',
        () async {
      var queried = false;
      handler = (_) async {
        queried = true;
        return http.Response('[]', 200);
      };

      expect(await dataSource.getCoursesByIds([]), isEmpty);
      expect(queried, isFalse);
    });

    test('getPublicCourses does NOT filter tenant client-side (RLS is the '
        'authority) and maps teacher rows + pagination', () async {
      http.BaseRequest? coursesRequest;
      handler = (request) async {
        if (request.url.path.endsWith('/rest/v1/courses')) {
          coursesRequest = request;
          return http.Response(
            jsonEncode([tCourseRow]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/rpc/get_courses_instructors')) {
          return http.Response(
            jsonEncode([]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return postgrestError('unexpected request', 'TEST404');
      };

      final courses = await dataSource.getPublicCourses(page: 2, limit: 10);

      expect(courses, hasLength(1));
      expect(courses.single.id, 'course-1');
      expect(courses.single.title, 'Flutter Mastery');
      // applyInstructorFields flattened the teacher join.
      expect(courses.single.instructorName, 'Ada Lovelace');
      expect(courses.single.instructorAvatar, 'https://example.com/ada.png');
      // Page 2 with limit 10 → PostgREST pagination via offset/limit query
      // params (postgrest 2.9.1's range() does NOT emit a Range header).
      expect(coursesRequest!.url.path, endsWith('/rest/v1/courses'));
      expect(coursesRequest!.url.queryParameters['offset'], '10');
      expect(coursesRequest!.url.queryParameters['limit'], '10');
      // Phase 10: tenant scoping is 100% server-side (RLS policy
      // courses_select_merged). The old client-side `.or(tenant_id...)`
      // filter was dead intent + a false-empty fallback — the request must
      // carry NO tenant constraint of any kind.
      expect(coursesRequest!.url.queryParameters.containsKey('or'), isFalse);
      expect(
        coursesRequest!.url.queryParameters.containsKey('tenant_id'),
        isFalse,
      );
    });
  });

  group('authenticated session', () {
    setUp(() async {
      await signIn();
    });

    test('getMyCourses maps the enrollment rows with the embedded course',
        () async {
      handler = (request) async {
        if (request.url.path.endsWith('/rest/v1/enrollments')) {
          return http.Response(
            jsonEncode([tEnrollmentRow]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return postgrestError('unexpected request', 'TEST404');
      };

      final enrollments = await dataSource.getMyCourses();

      expect(enrollments, hasLength(1));
      expect(enrollments.single.id, 'enr-1');
      expect(enrollments.single.userId, 'user-1');
      expect(enrollments.single.courseId, 'course-1');
      expect(enrollments.single.tenantId, 'tenant-1');
      expect(enrollments.single.course?.id, 'course-1');
      expect(enrollments.single.course?.title, 'Flutter Mastery');
    });

    test('getMyCourseEnrollment returns the enrolled row, or null when the '
        'user is not enrolled', () async {
      handler = (request) async {
        if (request.url.path.endsWith('/rest/v1/enrollments')) {
          return http.Response(
            jsonEncode(tEnrollmentRow),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return postgrestError('unexpected request', 'TEST404');
      };

      final enrollment = await dataSource.getMyCourseEnrollment('course-1');
      expect(enrollment, isNotNull);
      expect(enrollment!.courseId, 'course-1');

      handler = (request) async {
        if (request.url.path.endsWith('/rest/v1/enrollments')) {
          // maybeSingle with zero rows → JSON null body.
          return http.Response('null', 200);
        }
        return postgrestError('unexpected request', 'TEST404');
      };
      expect(await dataSource.getMyCourseEnrollment('course-x'), isNull);
    });

    test('getCourseOutline orders sections and lessons by order_index and '
        'sorts the payload client-side regardless of arrival order',
        () async {
      // Arrival order deliberately shuffled: sections [s2, s1], s2's
      // lessons [l22, l20], s1's lessons [l11, l10].
      const outlineRow = {
        'id': 'course-1',
        'tenant_id': 'tenant-1',
        'title': 'Flutter Mastery',
        'status': 'published',
        'is_discoverable': true,
        'teacher': null,
        'learning_objectives': [],
        'prerequisites': [],
        'sections': [
          {
            'id': 's2',
            'course_id': 'course-1',
            'tenant_id': 'tenant-1',
            'title': 'Section Two',
            'order_index': 2,
            'created_at': '2026-09-02T00:00:00Z',
            'lessons': [
              {
                'id': 'l22',
                'section_id': 's2',
                'course_id': 'course-1',
                'tenant_id': 'tenant-1',
                'title': 'Lesson 2.2',
                'order_index': 22,
                'created_at': '2026-09-02T00:00:00Z',
              },
              {
                'id': 'l20',
                'section_id': 's2',
                'course_id': 'course-1',
                'tenant_id': 'tenant-1',
                'title': 'Lesson 2.0',
                'order_index': 20,
                'created_at': '2026-09-02T00:00:00Z',
              },
            ],
          },
          {
            'id': 's1',
            'course_id': 'course-1',
            'tenant_id': 'tenant-1',
            'title': 'Section One',
            'order_index': 1,
            'created_at': '2026-09-01T00:00:00Z',
            'lessons': [
              {
                'id': 'l11',
                'section_id': 's1',
                'course_id': 'course-1',
                'tenant_id': 'tenant-1',
                'title': 'Lesson 1.1',
                'order_index': 11,
                'created_at': '2026-09-01T00:00:00Z',
              },
              {
                'id': 'l10',
                'section_id': 's1',
                'course_id': 'course-1',
                'tenant_id': 'tenant-1',
                'title': 'Lesson 1.0',
                'order_index': 10,
                'created_at': '2026-09-01T00:00:00Z',
              },
            ],
          },
        ],
      };

      http.BaseRequest? coursesRequest;
      handler = (request) async {
        if (request.url.path.endsWith('/rest/v1/courses')) {
          coursesRequest = request;
          return http.Response(
            jsonEncode(outlineRow),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/rest/v1/rpc/get_courses_instructors')) {
          // mergeInstructors enrichment: empty answer keeps the course as-is.
          return http.Response(
            jsonEncode([]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return postgrestError('unexpected request', 'TEST404');
      };

      final course = await dataSource.getCourseOutline('course-1');

      // Server-side: the outline query must carry explicit embed ordering —
      // a PostgREST embed has no guaranteed row order without it.
      expect(
        coursesRequest!.url.queryParameters['sections.order'],
        'order_index.asc.nullslast',
      );
      expect(
        coursesRequest!.url.queryParameters['sections.lessons.order'],
        'order_index.asc.nullslast',
      );

      // Client-side: even though the fake server ignored the order params
      // and returned shuffled rows, the mapped curriculum is sorted.
      expect(
        course.sections!.map((s) => s.id).toList(),
        ['s1', 's2'],
      );
      expect(
        course.sections!.first.lessons!.map((l) => l.id).toList(),
        ['l10', 'l11'],
      );
      expect(
        course.sections!.last.lessons!.map((l) => l.id).toList(),
        ['l20', 'l22'],
      );
    });

    test('getPublicCourses does NOT widen/narrow the tenant client-side — '
        'RLS (courses_select_merged) is the sole tenant authority', () async {
      http.BaseRequest? coursesRequest;
      handler = (request) async {
        if (request.url.path.endsWith('/rest/v1/courses')) {
          coursesRequest = request;
          return http.Response(
            jsonEncode([]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/rpc/get_courses_instructors')) {
          return http.Response(
            jsonEncode([]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return postgrestError('unexpected request', 'TEST404');
      };

      await dataSource.getPublicCourses(page: 1, limit: 10);

      // Phase 10: the cached-JWT-claim `.or(...)` filter was deleted — a
      // stale claim intersected with RLS produced empty/partial catalogs,
      // and the global-tenant branch could never survive the policy anyway.
      expect(coursesRequest!.url.queryParameters.containsKey('or'), isFalse);
      expect(
        coursesRequest!.url.queryParameters.containsKey('tenant_id'),
        isFalse,
      );
    });

    test('updateLessonProgress forwards the RPC params and completes',
        () async {
      http.Request? captured;
      handler = (request) async {
        if (request.url.path.endsWith('/rpc/update_lesson_progress')) {
          captured = request as http.Request;
          return http.Response('', 204);
        }
        return postgrestError('unexpected request', 'TEST404');
      };

      await dataSource.updateLessonProgress(
        courseId: 'course-1',
        lessonId: 'lesson-1',
        completed: true,
        progressPct: 100,
        watchTimeSec: 42,
      );

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['p_course_id'], 'course-1');
      expect(body['p_lesson_id'], 'lesson-1');
      expect(body['p_completed'], true);
      expect(body['p_progress_pct'], 100);
      expect(body['p_watch_time_sec'], 42);
    });

    test('getMyRating returns the rating value, or null when unrated',
        () async {
      handler = (request) async {
        if (request.url.path.endsWith('/rest/v1/course_ratings')) {
          return http.Response(
            jsonEncode({'rating': 4}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return postgrestError('unexpected request', 'TEST404');
      };
      expect(await dataSource.getMyRating('course-1'), 4);

      handler = (request) async {
        if (request.url.path.endsWith('/rest/v1/course_ratings')) {
          return http.Response('null', 200);
        }
        return postgrestError('unexpected request', 'TEST404');
      };
      expect(await dataSource.getMyRating('course-1'), isNull);
    });

    test('rateCourse maps the aggregate returned by the RPC', () async {
      handler = (request) async {
        if (request.url.path.endsWith('/rpc/rate_course')) {
          return http.Response(
            jsonEncode({
              'course_id': 'course-1',
              'rating': 4.25,
              'rating_count': 12,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return postgrestError('unexpected request', 'TEST404');
      };

      final aggregate = await dataSource.rateCourse(
        courseId: 'course-1',
        rating: 4,
      );

      expect(aggregate.courseId, 'course-1');
      expect(aggregate.rating, 4.25);
      expect(aggregate.ratingCount, 12);
    });

    test('getLessonContent marks has_access=true and maps the video path',
        () async {
      handler = (request) async {
        if (request.url.path.endsWith('/rpc/get_lesson_content')) {
          return http.Response(
            jsonEncode({
              'lessonId': 'lesson-1',
              'courseId': 'course-1',
              'videoPath': 'https://cdn.example.com/lesson-1.m3u8',
              'durationSec': 600,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return postgrestError('unexpected request', 'TEST404');
      };

      final content = await dataSource.getLessonContent('lesson-1');

      expect(content.lessonId, 'lesson-1');
      expect(content.courseId, 'course-1');
      expect(content.videoUrl, 'https://cdn.example.com/lesson-1.m3u8');
      expect(content.duration, 600);
      // Successfully fetching content implies access is granted.
      expect(content.hasAccess, isTrue);
    });

    test('getLessonContent maps an access-denied RPC rejection to an empty '
        'LessonContent with hasAccess=false instead of throwing', () async {
      handler = (request) async {
        if (request.url.path.endsWith('/rpc/get_lesson_content')) {
          return postgrestError('ACCESS_DENIED: not_enrolled', 'P0001');
        }
        return postgrestError('unexpected request', 'TEST404');
      };

      final content = await dataSource.getLessonContent('lesson-1');

      expect(content.lessonId, 'lesson-1');
      expect(content.courseId, '');
      expect(content.hasAccess, isFalse);
    });

    test('a real server error (non-access-denied) from get_lesson_content '
        'surfaces as ServerException', () async {
      handler = (request) async {
        if (request.url.path.endsWith('/rpc/get_lesson_content')) {
          return postgrestError('relation does not exist', '42P01');
        }
        return postgrestError('unexpected request', 'TEST404');
      };

      await expectLater(
        () => dataSource.getLessonContent('lesson-1'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.message, 'message', 'relation does not exist')
              .having((e) => e.code, 'code', '42P01'),
        ),
      );
    });

    test('getCourseProgressSummary maps the RPC aggregate, and a null '
        'response degrades to the zero summary', () async {
      handler = (request) async {
        if (request.url.path.endsWith('/rpc/get_course_progress_summary')) {
          return http.Response(
            jsonEncode({
              'courseId': 'course-1',
              'enrolledCount': 25,
              'avgProgress': 40.0,
              'completedCount': 4,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return postgrestError('unexpected request', 'TEST404');
      };

      final summary = await dataSource.getCourseProgressSummary('course-1');
      expect(summary.courseId, 'course-1');
      expect(summary.enrolledCount, 25);
      expect(summary.avgProgress, 40.0);
      expect(summary.completedCount, 4);

      handler = (request) async {
        if (request.url.path.endsWith('/rpc/get_course_progress_summary')) {
          return http.Response('null', 200);
        }
        return postgrestError('unexpected request', 'TEST404');
      };
      final empty = await dataSource.getCourseProgressSummary('course-1');
      expect(empty.enrolledCount, 0);
      expect(empty.completedCount, 0);
      expect(empty.avgProgress, 0.0);
    });

    test(
        'SECURITY CONTRACT: an AUTH_REQUIRED PostgrestException escaping to '
        'NetworkGuard comes out as SessionRevokedException, not a plain '
        'ServerException', () async {
      // The datasource pre-converts PostgrestException to ServerException
      // (documented pattern in every feature datasource) — historically
      // that pre-conversion meant the session-revocation check in
      // NetworkExceptionMapper never ran for those calls. This pins the
      // fixed behavior: a revoked session from ANY RPC (here
      // update_lesson_progress) must fire SessionRevocationHook and force
      // sign-out rather than look like an ordinary business error.
      handler = (request) async {
        if (request.url.path.endsWith('/rpc/update_lesson_progress')) {
          return postgrestError('AUTH_REQUIRED', 'P0001');
        }
        return postgrestError('unexpected request', 'TEST404');
      };

      await expectLater(
        () => dataSource.updateLessonProgress(
          courseId: 'course-1',
          lessonId: 'lesson-1',
          completed: false,
          progressPct: 10,
        ),
        throwsA(isA<SessionRevokedException>()),
      );
    });
  });
}
