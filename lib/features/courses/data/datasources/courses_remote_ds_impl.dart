import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/network_exception_mapper.dart';
import '../../../../core/network/network_guard.dart';
import '../../../../core/network/supabase_client.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/course_enrollment.dart';
import '../../domain/entities/course_progress_summary.dart';
import '../../domain/entities/lesson_content.dart';
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
            .eq('status', 'active')
            .eq('user_id', userId)
            .order('enrolled_at', ascending: false);

        return (response as List)
            .map((json) => CourseEnrollment.fromJson(json))
            .toList();
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

        return Course.fromJson(fullData);
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

        // Get tenant_id from user metadata OR fetch from course
        String? tenantId = SupabaseService
            .client.auth.currentUser?.userMetadata?['tenant_id'];

        if (tenantId == null) {
          final courseData = await SupabaseService.client
              .from('courses')
              .select('tenant_id')
              .eq('id', courseId)
              .single();
          tenantId = courseData['tenant_id'] as String?;
        }

        if (tenantId == null) {
          throw const ServerException(
              'Could not determine tenant_id for progress update'); // check-ignore
        }

        await SupabaseService.client.from('user_progress').upsert({
          'user_id': userId,
          'course_id': courseId,
          'lesson_id': lessonId,
          'tenant_id': tenantId,
          'completed': completed,
          'progress_pct': progressPct,
          if (completed) 'completed_at': DateTime.timestamp().toIso8601String(),
          'watch_time_sec': ?watchTimeSec,
          'last_watched': DateTime.timestamp().toIso8601String(),
        }, onConflict: 'user_id,course_id,lesson_id');

        // Log activity (best-effort; failures here must never fail the
        // progress write itself).
        try {
          await SupabaseService.client.rpc(
            'log_activity_async',
            params: {
              'p_user_id': userId,
              'p_type': completed ? 'lesson_completed' : 'lesson_progress',
              'p_details': {
                'course_id': courseId,
                'lesson_id': lessonId,
                'progress_pct': progressPct,
              },
            },
          );
        } catch (_) {
          // Best-effort — telemetry only, never propagate.
        }
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
        final currentUser = SupabaseService.client.auth.currentUser;
        // Check appMetadata first (system-set), then userMetadata
        var tenantId = currentUser?.appMetadata['tenant_id'] ??
            currentUser?.userMetadata?['tenant_id'];

        if (tenantId == null && currentUser != null) {
          final userData = await SupabaseService.client
              .from('users')
              .select('tenant_id')
              .eq('id', currentUser.id)
              .maybeSingle();
          tenantId = userData?['tenant_id'] as String?;
        }

        var query = SupabaseService.client
            .from('courses')
            .select('''
            *,
            ${CoursesQueries.teacherJoin},
            ${CoursesQueries.lightSectionsWithLessons}
          ''')
            .eq('status', 'published')
            .eq('is_discoverable', true);

        if (tenantId != null && tenantId is String && tenantId.isNotEmpty) {
          // Show courses that are either system-wide (global) OR belong to the user's tenant
          query = query.or(
              'tenant_id.eq.00000000-0000-0000-0000-000000000001,tenant_id.eq.$tenantId');
        } else {
          // Fallback: show only system-wide courses
          query =
              query.eq('tenant_id', '00000000-0000-0000-0000-000000000001');
        }

        final response = await query
            .range(offset, offset + limit - 1)
            .order('created_at', ascending: false);

        return (response as List).map((json) {
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

          return Course.fromJson(fullData);
        }).toList();
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
            .eq('status', 'active');

        return (response as List<dynamic>)
            .map((json) {
              final row = json as Map<String, dynamic>;
              return row['course_id'] as String;
            })
            .toSet();
      });
    } catch (_) {
      // Deliberately swallowed: an empty subscribed-set degrades the UI
      // gracefully (courses just show as "not subscribed") rather than
      // failing a screen over what is usually a secondary/enrichment
      // query. Kept as the pre-existing behavior; only the underlying
      // guard's timeout/retry/classification changed.
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

        return (response as List).map((json) {
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

          return Course.fromJson(fullData);
        }).toList();
      } on PostgrestException catch (e) {
        throw ServerException(e.message, e.code); // check-ignore
      } catch (e) {
        if (e is AppException) rethrow;
        throw NetworkExceptionMapper.map(e);
      }
    });
  }
}
