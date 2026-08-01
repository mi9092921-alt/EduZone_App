import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/supabase_client.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/course_enrollment.dart';
import '../../domain/entities/course_progress_summary.dart';
import '../../domain/entities/lesson_content.dart';
import 'courses_remote_ds.dart';
import 'lesson_access_error_classifier.dart';

class CoursesRemoteDataSourceImpl implements CoursesRemoteDataSource {
  @override
  Future<List<CourseEnrollment>> getMyCourses() async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) throw const ServerException('User not authenticated');

      final response = await SupabaseService.client
          .from('enrollments')
          .select('''
            *,
            course:courses!course_id(
              *,
              sections(
                id,
                course_id,
                tenant_id,
                title,
                lessons(id, section_id, course_id, title, is_preview, duration_sec)
              )
            )
          ''')
          .eq('status', 'active')
          .eq('user_id', userId)
          .order('enrolled_at', ascending: false);

      return (response as List)
          .map((json) => CourseEnrollment.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
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
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;

      final courseResponse = await SupabaseService.client
          .from('courses')
          .select('''
            *,
            teacher:users!teacher_id(first_name, last_name, avatar_url),
            learning_objectives:course_learning_objectives(id, objective, order_index),
            prerequisites:course_prerequisites!course_prerequisites_course_tenant_fkey(
              prerequisite_course_id,
              prerequisite_course:courses!prerequisite_course_id(title)
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
          .single()
          .timeout(const Duration(seconds: 15));

      final fullData = Map<String, dynamic>.from(courseResponse);

      // Defensive client-side filter to keep only user_progress for current user
      if (fullData['sections'] is List) {
        for (final section in fullData['sections'] as List) {
          if (section is Map && section['lessons'] is List) {
            for (final lesson in section['lessons'] as List) {
              if (lesson is Map && lesson['user_progress'] is List) {
                final rawProgressList = lesson['user_progress'] as List;
                if (userId == null) {
                  lesson['user_progress'] = [];
                } else {
                  lesson['user_progress'] = rawProgressList
                      .where((p) => p is Map && p['user_id'] == userId)
                      .toList();
                }
              }
            }
          }
        }
      }

      // Map joined teacher data to flat instructor fields
      final teacher = courseResponse['teacher'] as Map?;
      if (teacher != null) {
        final firstName = teacher['first_name'] as String? ?? '';
        final lastName = teacher['last_name'] as String? ?? '';
        fullData['instructor_name'] = '$firstName $lastName'.trim();
        fullData['instructor_avatar'] = teacher['avatar_url'];
      }

      // Flatten & sort learning_objectives: [{objective: "...", order_index: 0}] -> ["..."]
      final rawObjectives = fullData['learning_objectives'];
      if (rawObjectives is List) {
        final sortedObjs = List<Map<String, dynamic>>.from(
          rawObjectives.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
        )..sort((a, b) => ((a['order_index'] as int? ?? 0)).compareTo(b['order_index'] as int? ?? 0));

        fullData['learning_objectives'] = sortedObjs
            .map((o) => o['objective'] as String? ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      }

      // Flatten prerequisites: [{prerequisite_course_id: "...", prerequisite_course: {title: "..."}}] -> ["Title"]
      final rawPrereqs = fullData['prerequisites'];
      if (rawPrereqs is List) {
        fullData['prerequisites'] = rawPrereqs
            .whereType<Map>()
            .map((p) {
              final prereqCourse = p['prerequisite_course'] as Map?;
              if (prereqCourse != null && prereqCourse['title'] is String) {
                return prereqCourse['title'] as String;
              }
              return p['prerequisite_course_id'] as String? ?? '';
            })
            .where((s) => s.isNotEmpty)
            .toList();
      }

      return Course.fromJson(fullData);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<CourseEnrollment?> getMyCourseEnrollment(String courseId) async {
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
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> updateLessonProgress({
    required String courseId,
    required String lessonId,
    required bool completed,
    required double progressPct,
    int? watchTimeSec,
  }) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) throw const ServerException('User not authenticated');

      // Get tenant_id from user metadata OR fetch from course
      String? tenantId =
          SupabaseService.client.auth.currentUser?.userMetadata?['tenant_id'];

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
            'Could not determine tenant_id for progress update');
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

      // Log activity
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
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<Course>> getPublicCourses({
    required int page,
    required int limit,
  }) async {
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
            teacher:users!teacher_id(first_name, last_name, avatar_url),
            sections(
              id,
              course_id,
              tenant_id,
              title,
              lessons(id, section_id, course_id, title, is_preview, duration_sec)
            )
          ''')
          .eq('status', 'published')
          .eq('is_discoverable', true);

      if (tenantId != null && tenantId is String && tenantId.isNotEmpty) {
        // Show courses that are either system-wide (global) OR belong to the user's tenant
        query = query.or('tenant_id.eq.00000000-0000-0000-0000-000000000001,tenant_id.eq.$tenantId');
      } else {
        // Fallback: show only system-wide courses
        query = query.eq('tenant_id', '00000000-0000-0000-0000-000000000001');
      }

      final response = await query
          .range(offset, offset + limit - 1)
          .order('created_at', ascending: false);

      return (response as List).map((json) {
        final rawJson = json as Map<String, dynamic>;
        final fullData = Map<String, dynamic>.from(rawJson);

        // ── Instructor name ──────────────────────────────────────────────
        final teacher = rawJson['teacher'] as Map?;
        if (teacher != null) {
          final firstName = teacher['first_name'] as String? ?? '';
          final lastName = teacher['last_name'] as String? ?? '';
          fullData['instructor_name'] = '$firstName $lastName'.trim();
          fullData['instructor_avatar'] = teacher['avatar_url'];
        }

        // ── Lesson count backfill ────────────────────────────────────────
        // courses.total_lessons is a stored counter (NOT NULL DEFAULT 0).
        // Courses seeded before the patch-16 trigger still carry 0 instead
        // of the real count. Because 0 != null, the ?? fallback in the
        // presenter never fires. We recompute from the already-joined
        // sections → lessons payload at zero extra network cost.
        final storedTotal = (rawJson['total_lessons'] as num?)?.toInt() ?? 0;
        if (storedTotal == 0) {
          final sections = rawJson['sections'] as List? ?? const [];
          final computed = sections.fold<int>(0, (acc, s) {
            final lessons = (s as Map)['lessons'] as List? ?? const [];
            return acc + lessons.length;
          });
          fullData['total_lessons'] = computed;
        }

        if (kDebugMode) {
          final id = rawJson['id'];
          final title = rawJson['title'];
          final stored = (rawJson['total_lessons'] as num?)?.toInt() ?? 0;
          final inMap = fullData['total_lessons'];
          debugPrint(
            '[Discover] $title ($id) '
            'stored=$stored → injected=$inMap',
          );
        }

        return Course.fromJson(fullData);
      }).toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<Set<String>> getUserSubscribedCourseIds() async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) throw const ServerException('User not authenticated');

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
    } on PostgrestException {
      return <String>{};
    } catch (_) {
      return <String>{};
    }
  }

  @override
  Future<void> enrollInCourse(String courseId) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) throw const ServerException('User not authenticated');

      await SupabaseService.client.rpc(
        'enroll_in_course',
        params: {'p_course_id': courseId},
      );
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
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
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) throw const ServerException('User not authenticated');

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
        response is Map<String, dynamic>
            ? response
            : response as Map,
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
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  // ── Progress Summary RPC ──────────────────────────────────
  @override
  Future<CourseProgressSummary> getCourseProgressSummary(
      String courseId) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        throw const ServerException('User not authenticated');
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
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<Course>> getCoursesByIds(List<String> ids) async {
    try {
      if (ids.isEmpty) return [];

      final response = await SupabaseService.client
          .from('courses')
          .select('''
            *,
            teacher:users!teacher_id(first_name, last_name, avatar_url),
            sections(
              id,
              course_id,
              tenant_id,
              title,
              lessons(id, section_id, course_id, title, is_preview, duration_sec)
            )
          ''')
          .inFilter('id', ids)
          .eq('status', 'published');

      return (response as List).map((json) {
        final rawJson = json as Map<String, dynamic>;
        final fullData = Map<String, dynamic>.from(rawJson);

        // ── Instructor name ──────────────────────────────────────────────
        final teacher = rawJson['teacher'] as Map?;
        if (teacher != null) {
          final firstName = teacher['first_name'] as String? ?? '';
          final lastName = teacher['last_name'] as String? ?? '';
          fullData['instructor_name'] = '$firstName $lastName'.trim();
          fullData['instructor_avatar'] = teacher['avatar_url'];
        }

        // ── Lesson count backfill (same logic as getPublicCourses) ───────
        final storedTotal = (rawJson['total_lessons'] as num?)?.toInt() ?? 0;
        if (storedTotal == 0) {
          final sections = rawJson['sections'] as List? ?? const [];
          final computed = sections.fold<int>(0, (acc, s) {
            final lessons = (s as Map)['lessons'] as List? ?? const [];
            return acc + lessons.length;
          });
          fullData['total_lessons'] = computed;
        }

        return Course.fromJson(fullData);
      }).toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
