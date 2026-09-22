import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/network_exception_mapper.dart';
import '../../../../core/network/network_guard.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/global_error_handler.dart';
import '../../../../shared/models/course.dart';
import '../../../../shared/models/course_rating.dart';
import '../../../../shared/models/lesson_content.dart';
import '../../domain/entities/course_enrollment.dart';
import '../../domain/entities/course_progress_summary.dart';
import 'courses_json_mapper.dart';
import 'courses_queries.dart';
import 'courses_remote_ds.dart';
import 'lesson_access_error_classifier.dart';

// ─────────────────────────────────────────────────────────────────────────
// كان هذا الملف أصلاً 551 سطرًا. الجزء الأكبر من الحجم كان منطق تحويل JSON
// (تسطيح بيانات المعلّم، إعادة حساب عدد الدروس، ترتيب الأهداف/المتطلبات
// السابقة، فلترة تقدّم المستخدم) وكان **مكرراً حرفياً** بين 2-3 methods.
// استخرجته إلى courses_json_mapper.dart:
//   - CoursesJsonMapper.applyInstructorFields()          (مكرر 3 مرات → 1)
//   - CoursesJsonMapper.backfillTotalLessons()            (مكرر مرتين → 1)
//   - CoursesJsonMapper.flattenLearningObjectives()
//   - CoursesJsonMapper.flattenPrerequisites()
//   - CoursesJsonMapper.filterUserProgressForCurrentUser()
// كل هذه الدوال صرفة (Map في → Map معدَّل)، بلا أي اعتماد على Supabase،
// وبالتالي قابلة للاختبار مباشرة بدون mocking شبكة على الإطلاق — وهو ما لم
// يكن ممكناً قبل الفصل (كان لازم تمر عبر كامل هذا الـ datasource).
//
// Section 13 hardening pass: every read below (getMyCourses,
// getCourseOutline, getMyCourseEnrollment, getPublicCourses,
// getUserSubscribedCourseIds, getLessonContent,
// getCourseProgressSummary, getCoursesByIds) now goes through
// `NetworkGuard.read`, which (a) applies a client-side timeout that was
// previously present on exactly one of these eight calls, and (b)
// retries a bounded number of times with backoff, but *only* when the
// failure classifies as a transient connectivity/timeout issue -- never
// for a real Postgrest/business error. Writes (updateLessonProgress,
// enrollInCourse) go through `NetworkGuard.write`, which times out and
// maps errors but never auto-retries, per the project instructions'
// explicit "never retry non-idempotent operations blindly" rule.
// ─────────────────────────────────────────────────────────────────────────

class CoursesRemoteDataSourceImpl implements CoursesRemoteDataSource {
  @override
  Future<List<CourseEnrollment>> getMyCourses() async {
    return NetworkGuard.read(() async {
      try {
        final userId = SupabaseService.client.auth.currentUser?.id;
        if (userId == null) {
          throw const ServerException('User not authenticated'); // check-ignore
        }

        final response = await SupabaseService.client
            .from('enrollments')
            .select('''
            *,
            course:courses!course_id(
              *,
              ${CoursesQueries.lightSectionsWithLessons}
            )
          ''')
            // Phase 10: was `.eq('status', 'active')` — but the server's
            // progress recalc flips enrollments.status to 'completed' at
            // 100% (07_functions.sql:7266/7294), and every server-side
            // access check treats ('active','completed') as entitled
            // (07_functions.sql:2283/3675). The active-only filter made a
            // course vanish from My Courses the instant it was finished.
            .inFilter('status', ['active', 'completed'])
            .eq('user_id', userId)
            .order('enrolled_at', ascending: false);

        return (response as List).map((json) {
          final enrollmentJson = Map<String, dynamic>.from(json as Map);
          final courseJson = enrollmentJson['course'];
          if (courseJson is Map) {
            final sortedCourse = Map<String, dynamic>.from(courseJson);
            CoursesJsonMapper.sortCurriculum(sortedCourse);
            enrollmentJson['course'] = sortedCourse;
          }
          return _safeEnrollmentFromJson(enrollmentJson);
        }).whereType<CourseEnrollment>().toList();
      } on PostgrestException catch (e) {
        throw ServerException(e.message, e.code); // check-ignore
      } catch (e) {
        if (e is AppException) rethrow;
        throw NetworkExceptionMapper.map(e);
      }
    });
  }

  // ── v11: getCourseDetails now delegates to get_course_outline RPC ──
  // This ensures that lesson metadata (titles, duration) is returned
  // while video_path (stored in lesson_contents) is never exposed via
  // a direct PostgREST join. The RPC also merges user_progress for
  // enrolled users automatically.
  @override
  Future<Course> getCourseDetails(String courseId) async {
    return getCourseOutline(courseId);
  }

  // ── v11 NEW: get_course_outline RPC ───────────────────────────────
  /// Returns course structure (sections + lesson metadata) WITHOUT
  /// any video URLs. Safe for both enrolled and unenrolled callers.
  @override
  Future<Course> getCourseOutline(String courseId) async {
    return NetworkGuard.read(() async {
      try {
        final userId = SupabaseService.client.auth.currentUser?.id;

        final courseResponse = await SupabaseService.client
            .from('courses')
            .select('''
            *,
            ${CoursesQueries.teacherJoin},
            learning_objectives:course_learning_objectives(id, objective, order_index),
            prerequisites:course_prerequisites!course_prerequisites_course_tenant_fkey(
              prerequisite_course_id,
              prerequisite_course:courses!course_prerequisites_prereq_tenant_fkey(title)
            ),
            sections(
              id,
              course_id,
              tenant_id,
              title,
              description,
              order_index,
              is_published,
              created_at,
              updated_at,
              lessons(
                id,
                section_id,
                course_id,
                tenant_id,
                title,
                order_index,
                is_published,
                is_preview,
                duration_sec,
                created_at,
                updated_at,
                user_progress(
                  id,
                  user_id,
                  course_id,
                  lesson_id,
                  tenant_id,
                  completed,
                  completed_at,
                  progress_pct,
                  watch_time_sec,
                  last_watched,
                  created_at,
                  updated_at
                )
              )
            )
          ''')
            .eq('id', courseId)
            // Deterministic curriculum order: a PostgREST embed has NO
            // guaranteed row order without an explicit order param, so
            // sections and lessons otherwise come back in whatever order
            // the planner picks (observed as shuffled lessons in the
            // accordion, curriculum preview, and player sidebar).
            .order(
              'order_index',
              referencedTable: 'sections',
              ascending: true,
            )
            .order(
              'order_index',
              referencedTable: 'sections.lessons',
              ascending: true,
            )
            .single();

        final fullData = Map<String, dynamic>.from(courseResponse);

        // Defensive client-side filter to keep only user_progress for current user
        CoursesJsonMapper.filterUserProgressForCurrentUser(fullData, userId);

        // Map joined teacher data to flat instructor fields
        CoursesJsonMapper.applyInstructorFields(
          target: fullData,
          teacherJson: courseResponse['teacher'] as Map?,
        );

        CoursesJsonMapper.flattenLearningObjectives(fullData);
        CoursesJsonMapper.flattenPrerequisites(fullData);
        CoursesJsonMapper.sortCurriculum(fullData);

        // The users SELECT RLS hides teacher rows from students, so the
        // PostgREST teacher join above resolves to NULL for them —
        // resolve the instructor display fields via the RPC instead.
        final course = Course.fromJson(fullData);
        final merged = await mergeInstructors([course]);
        return merged.first;
      } catch (e) {
        if (e is AppException) rethrow;
        throw NetworkExceptionMapper.map(e);
      }
    });
  }

  @override
  Future<CourseEnrollment?> getMyCourseEnrollment(String courseId) async {
    return NetworkGuard.read(() async {
      try {
        final userId = SupabaseService.client.auth.currentUser?.id;
        if (userId == null) return null;

        final response = await SupabaseService.client
            .from('enrollments')
            .select('*, course:courses!course_id(*)')
            .eq('course_id', courseId)
            .eq('user_id', userId)
            .maybeSingle();

        if (response == null) return null;
        return CourseEnrollment.fromJson(response);
      } on PostgrestException catch (e) {
        throw ServerException(e.message, e.code); // check-ignore
      } catch (e) {
        if (e is AppException) rethrow;
        throw NetworkExceptionMapper.map(e);
      }
    });
  }

  // ── update_lesson_progress RPC ────────────────────────────────────
  /// Calls the `update_lesson_progress(p_course_id, p_lesson_id,
  /// p_progress_pct, p_completed, p_watch_time_sec)` RPC.
  ///
  /// Tenant, lesson/course ownership, and enrollment/preview access are
  /// all derived and checked server-side inside the RPC (see
  /// `07_functions.sql`) -- this datasource no longer resolves or sends
  /// `tenant_id` itself. That removes the extra `courses` round-trip this
  /// method previously needed when `userMetadata['tenant_id']` was
  /// absent/stale, and folds the (previously separate, best-effort)
  /// activity-log call into the same RPC transaction.
  @override
  Future<void> updateLessonProgress({
    required String courseId,
    required String lessonId,
    required bool completed,
    required double progressPct,
    int? watchTimeSec,
  }) async {
    return NetworkGuard.write(() async {
      try {
        final userId = SupabaseService.client.auth.currentUser?.id;
        if (userId == null) {
          throw const ServerException('User not authenticated'); // check-ignore
        }

        await SupabaseService.client.rpc(
          'update_lesson_progress',
          params: {
            'p_course_id': courseId,
            'p_lesson_id': lessonId,
            'p_progress_pct': progressPct,
            'p_completed': completed,
            'p_watch_time_sec': watchTimeSec,
          },
        );
      } on PostgrestException catch (e) {
        throw ServerException(e.message, e.code); // check-ignore
      } catch (e) {
        if (e is AppException) rethrow;
        throw NetworkExceptionMapper.map(e);
      }
    });
  }

  @override
  Future<List<Course>> getPublicCourses({
    required int page,
    required int limit,
  }) async {
    return NetworkGuard.read(() async {
      try {
        final offset = (page - 1) * limit;

        // Phase 10: the manual tenant filter that used to live here was
        // deleted, not fixed. RLS policy courses_select_merged
        // (09_rls.sql:1290) already scopes every authenticated read to
        // tenant_id = get_current_tenant_id(), so:
        //  * the `.or('tenant_id.eq.<global>,tenant_id.eq.<cached>')` branch
        //    was dead intent — the global tenant is NOT exempted in RLS, so
        //    "system-wide" rows never survived the policy anyway, and the
        //    cached-tenant branch merely duplicated the policy (with a
        //    STALE value when the cached claim lagged the token);
        //  * the fallback `.eq('tenant_id', <global>)` (cached claim
        //    missing) intersected with RLS tenant=T to a guaranteed-empty
        //    Discover with no error surfaced.
        // Tenant scoping is the server's job — trust RLS (AGENTS.md).
        final query = SupabaseService.client
            .from('courses')
            .select('''
            *,
            ${CoursesQueries.teacherJoin},
            ${CoursesQueries.lightSectionsWithLessons}
          ''')
            .eq('status', 'published')
            .eq('is_discoverable', true);

        final response = await query
            .range(offset, offset + limit - 1)
            .order('created_at', ascending: false)
            // Unique tiebreaker: rows sharing `created_at` (bulk seed data)
            // made the offset window unstable across pages — a course could
            // be skipped or served twice between page fetches. The secondary
            // id order pins every row to exactly one offset position.
            .order('id', ascending: false);

        final courses = (response as List).map((json) {
          final rawJson = json as Map<String, dynamic>;
          final fullData = Map<String, dynamic>.from(rawJson);

          CoursesJsonMapper.applyInstructorFields(
            target: fullData,
            teacherJson: rawJson['teacher'] as Map?,
          );
          CoursesJsonMapper.backfillTotalLessons(
            rawJson: rawJson,
            target: fullData,
            debugLog: true,
          );
          CoursesJsonMapper.sortCurriculum(fullData);

          return _safeCourseFromJson(fullData);
        }).whereType<Course>().toList();

        return mergeInstructors(courses);
      } on PostgrestException catch (e) {
        throw ServerException(e.message, e.code); // check-ignore
      } catch (e) {
        if (e is AppException) rethrow;
        throw NetworkExceptionMapper.map(e);
      }
    });
  }

  @override
  Future<Set<String>> getUserSubscribedCourseIds() async {
    try {
      return await NetworkGuard.read(() async {
        final userId = SupabaseService.client.auth.currentUser?.id;
        if (userId == null) {
          throw const ServerException('User not authenticated'); // check-ignore
        }

        // Use direct query instead of RPC to avoid dependency on missing database function
        final response = await SupabaseService.client
            .from('enrollments')
            .select('course_id')
            .eq('user_id', userId)
            // Same Phase 10 fix as getMyCourses: 'completed' enrollments are
            // still entitled (server access checks accept active+completed),
            // so a finished course must keep its "enrolled" CTA/routing.
            .inFilter('status', ['active', 'completed']);

        return (response as List<dynamic>)
            .map((json) {
              final row = json as Map<String, dynamic>;
              return row['course_id'] as String;
            })
            .toSet();
      });
    } catch (e, stack) {
      // Deliberately swallowed: an empty subscribed-set degrades the UI
      // gracefully (courses just show as "not subscribed") rather than
      // failing a screen over what is usually a secondary/enrichment
      // query. Kept as the pre-existing behavior — but a swallowed
      // outage must leave a diagnostic record (connectivity-shaped
      // failures classify as noise inside logError and stay
      // console-only; a real server error reaches Sentry).
      GlobalErrorHandler.logError(e, stack);
      return <String>{};
    }
  }

  @override
  Future<void> enrollInCourse(String courseId) async {
    return NetworkGuard.write(() async {
      try {
        final userId = SupabaseService.client.auth.currentUser?.id;
        if (userId == null) {
          throw const ServerException('User not authenticated'); // check-ignore
        }

        await SupabaseService.client.rpc(
          'enroll_in_course',
          params: {'p_course_id': courseId},
        );
      } on PostgrestException catch (e) {
        throw ServerException(e.message, e.code); // check-ignore
      } catch (e) {
        if (e is AppException) rethrow;
        throw NetworkExceptionMapper.map(e);
      }
    });
  }

  // ── course ratings (see docs §2.12) ──────────────────────────────
  @override
  Future<int?> getMyRating(String courseId) async {
    return NetworkGuard.read(() async {
      try {
        final response = await SupabaseService.client
            .from('course_ratings')
            .select('rating')
            .eq('course_id', courseId)
            .maybeSingle();
        return (response?['rating'] as num?)?.toInt();
      } on PostgrestException catch (e) {
        throw ServerException(e.message, e.code); // check-ignore
      } catch (e) {
        if (e is AppException) rethrow;
        throw NetworkExceptionMapper.map(e);
      }
    });
  }

  @override
  Future<CourseRatingAggregate> rateCourse({
    required String courseId,
    required int rating,
  }) async {
    return NetworkGuard.write(() async {
      try {
        final response = await SupabaseService.client.rpc(
          'rate_course',
          params: {'p_course_id': courseId, 'p_rating': rating},
        );
        return CourseRatingAggregate.fromJson(
          Map<String, dynamic>.from(response as Map),
        );
      } on PostgrestException catch (e) {
        throw ServerException(e.message, e.code); // check-ignore
      } catch (e) {
        if (e is AppException) rethrow;
        throw NetworkExceptionMapper.map(e);
      }
    });
  }

  // ── instructor resolution (see docs §2.13) ───────────────────────
  @override
  Future<Map<String, CourseInstructorInfo>> fetchInstructors(
    List<String> courseIds,
  ) async {
    if (courseIds.isEmpty) return const {};

    return NetworkGuard.read(() async {
      try {
        final response = await SupabaseService.client.rpc(
          'get_courses_instructors',
          params: {'p_course_ids': courseIds},
        );
        final rows = (response as List).whereType<Map>().map(
              (row) => Map<String, dynamic>.from(row),
            );
        return {
          for (final row in rows)
            row['course_id'] as String: CourseInstructorInfo.fromJson(row),
        };
      } on PostgrestException catch (e) {
        throw ServerException(e.message, e.code); // check-ignore
      } catch (e) {
        if (e is AppException) rethrow;
        throw NetworkExceptionMapper.map(e);
      }
    });
  }

  /// Best-effort enrichment: patches instructor name/avatar resolved via
  /// the `get_courses_instructors` RPC onto already-mapped courses. A
  /// failure here is deliberately swallowed (same degradation class as
  /// getUserSubscribedCourseIds): cards render without an instructor line
  /// rather than failing an entire screen over secondary enrichment.
  Future<List<Course>> mergeInstructors(List<Course> courses) async {
    if (courses.isEmpty) return courses;
    try {
      final infos = await fetchInstructors(courses.map((c) => c.id).toList());
      if (infos.isEmpty) return courses;
      return [
        for (final course in courses)
          _withInstructor(course, infos[course.id]),
      ];
    } catch (e) {
      if (e is AppException) {
        // Deliberate degradation — see doc comment above.
      }
      return courses;
    }
  }

  Course _withInstructor(Course course, CourseInstructorInfo? info) {
    if (info == null) return course;
    return course.copyWith(
      instructorName: info.name,
      instructorAvatar: info.avatarUrl,
    );
  }

  // ── v11 NEW: get_lesson_content RPC ──────────────────────────────
  /// Calls the `get_lesson_content(lesson_id, client_ip, device_id)` RPC.
  ///
  /// The RPC checks enrollment (or is_preview), logs the access in
  /// `lesson_access_log`, and returns the lesson's video_path.
  ///
  /// Throws [ServerException] with a clear message when the user is
  /// not authorized (e.g. not enrolled and not a preview lesson).
  @override
  Future<LessonContent> getLessonContent(String lessonId) async {
    return NetworkGuard.read(() async {
      try {
        final userId = SupabaseService.client.auth.currentUser?.id;
        if (userId == null) {
          throw const ServerException('User not authenticated'); // check-ignore
        }

        final response = await SupabaseService.client.rpc(
          'get_lesson_content',
          params: {'p_lesson_id': lessonId},
        );

        if (response == null) {
          return LessonContent(
            lessonId: lessonId,
            courseId: '',
          );
        }

        final Map<String, dynamic> contentJson = Map<String, dynamic>.from(
          response is Map<String, dynamic> ? response : response as Map,
        );

        // Successfully fetching content implies access is granted
        contentJson['has_access'] = true;

        return LessonContent.fromJson(contentJson);
      } on PostgrestException catch (e) {
        // Return hasAccess = false if access is denied instead of throwing an
        // exception. Any other Postgres error (e.g. lesson not found, a real
        // server-side bug, rate limiting) must surface as a real error instead
        // of being silently reported to the UI as "no access".
        if (LessonAccessErrorClassifier.isAccessDenied(e)) {
          return LessonContent(
            lessonId: lessonId,
            courseId: '',
          );
        }
        throw ServerException(e.message, e.code); // check-ignore
      } catch (e) {
        if (e is AppException) rethrow;
        throw NetworkExceptionMapper.map(e);
      }
    });
  }

  // ── Progress Summary RPC ──────────────────────────────────
  @override
  Future<CourseProgressSummary> getCourseProgressSummary(
      String courseId) async {
    return NetworkGuard.read(() async {
      try {
        final userId = SupabaseService.client.auth.currentUser?.id;
        if (userId == null) {
          throw const ServerException('User not authenticated'); // check-ignore
        }

        final response = await SupabaseService.client.rpc(
          'get_course_progress_summary',
          params: {'p_course_id': courseId},
        );

        if (response == null) {
          return const CourseProgressSummary();
        }

        final Map<String, dynamic> data = response is Map<String, dynamic>
            ? response
            : Map<String, dynamic>.from(response as Map);

        return CourseProgressSummary.fromJson(data);
      } on PostgrestException catch (e) {
        throw ServerException(e.message, e.code); // check-ignore
      } catch (e) {
        if (e is AppException) rethrow;
        throw NetworkExceptionMapper.map(e);
      }
    });
  }

  @override
  Future<List<Course>> getCoursesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    return NetworkGuard.read(() async {
      try {
        final response = await SupabaseService.client
            .from('courses')
            .select('''
            *,
            ${CoursesQueries.teacherJoin},
            ${CoursesQueries.lightSectionsWithLessons}
          ''')
            .inFilter('id', ids)
            .eq('status', 'published');

        final courses = (response as List).map((json) {
          final rawJson = json as Map<String, dynamic>;
          final fullData = Map<String, dynamic>.from(rawJson);

          CoursesJsonMapper.applyInstructorFields(
            target: fullData,
            teacherJson: rawJson['teacher'] as Map?,
          );
          CoursesJsonMapper.backfillTotalLessons(
            rawJson: rawJson,
            target: fullData,
          );
          CoursesJsonMapper.sortCurriculum(fullData);

          return _safeCourseFromJson(fullData);
        }).whereType<Course>().toList();

        final merged = await mergeInstructors(courses);
        // The Saved screen contract is "most recently bookmarked first": the
        // caller passes ids already ordered by the local bookmarks table
        // (created_at DESC), but PostgREST returns rows in arbitrary order
        // (no .order on an inFilter query). Restore the caller's order so
        // the saved list cannot reshuffle between refetches.
        final position = {
          for (final (index, id) in ids.indexed) id: index,
        };
        merged.sort(
          (a, b) => (position[a.id] ?? ids.length)
              .compareTo(position[b.id] ?? ids.length),
        );
        return merged;
      } on PostgrestException catch (e) {
        throw ServerException(e.message, e.code); // check-ignore
      } catch (e) {
        if (e is AppException) rethrow;
        throw NetworkExceptionMapper.map(e);
      }
    });
  }

  // ── Per-row mapping resilience ─────────────────────────────────────
  // A single malformed row (a null in a non-nullable Course field, a
  // non-ISO date, an unexpected embed shape) used to throw out of the
  // row-mapping loop and fail the ENTIRE list — one bad row in `courses`
  // or `enrollments` turned the catalog/My Courses/Saved screens into a
  // permanent AsyncError whose retry could never succeed (the corruption
  // is server-side data, not a transient fault). Rows that fail mapping
  // are now skipped with a diagnostic record (mirroring the
  // LessonProgressOutboxStore policy: discard-and-log, never guess);
  // genuine network/Postgrest failures keep failing the whole call so
  // they stay retryable.
  Course? _safeCourseFromJson(Map<String, dynamic> json) {
    try {
      return Course.fromJson(json);
    } catch (e, stack) {
      GlobalErrorHandler.logError(e, stack);
      return null;
    }
  }

  CourseEnrollment? _safeEnrollmentFromJson(Map<String, dynamic> json) {
    try {
      return CourseEnrollment.fromJson(json);
    } catch (e, stack) {
      GlobalErrorHandler.logError(e, stack);
      return null;
    }
  }
}
