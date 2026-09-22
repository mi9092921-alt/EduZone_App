import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/network_exception_mapper.dart';
import '../../../../core/network/network_guard.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../shared/models/course.dart';
import '../../../../shared/models/todo_item.dart';
import '../../domain/entities/resume_lesson.dart';
import 'home_remote_datasource.dart';

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final SupabaseClient _client;

  HomeRemoteDataSourceImpl({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  @override
  Future<List<ResumeLesson>> getResumeLessons() async {
    return NetworkGuard.read(() async {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return <ResumeLesson>[];

      final enrollmentResponse = await _client
          .from('enrollments')
          .select('course_id')
          .eq('user_id', userId)
          // Phase 10 (re-scan NEW-2): same active+completed rule as
          // getMyCourses/getUserSubscribedCourseIds/getRecentCourses — a
          // 100%-flipped enrollment with lagging user_progress rows must not
          // vanish from Resume while persisting in My Courses.
          .inFilter('status', ['active', 'completed']);
      final enrolledCourseIds = (enrollmentResponse as List)
          .map((row) => (row as Map)['course_id'] as String)
          .toSet()
          .toList();
      if (enrolledCourseIds.isEmpty) return <ResumeLesson>[];

      final response = await _client
          .from('user_progress')
          .select('''
            lesson_id,
            completed,
            progress_pct,
            last_watched,
            course:courses!user_progress_course_id_fkey(id, title, thumbnail_url),
            lesson:lessons(id, title, section_id, section:sections(title))
          ''')
          .eq('user_id', userId)
          .eq('completed', false)
          .inFilter('course_id', enrolledCourseIds)
          .order('last_watched', ascending: false)
          // The per-course dedupe below keeps ONE row per course, but this
          // cap applies BEFORE it: a user with 30+ incomplete-lesson rows
          // concentrated in one course pushed every other course's rows past
          // the window, collapsing the section to a single card. 120 rows
          // (~4 lessons x 30 courses of recent activity) is still a bounded,
          // cheap fetch while giving the dedupe a fair window; the UI caps
          // the section at 3 cards regardless.
          .limit(120);

      final lessons = <ResumeLesson>[];
      final seenCourseIds = <String>{};
      for (final row in response as List) {
        final data = Map<String, dynamic>.from(row as Map);
        final course = data['course'] as Map?;
        final lesson = data['lesson'] as Map?;
        final section = lesson?['section'] as Map?;
        if (course == null || lesson == null) continue;

        final courseId = course['id'] as String;
        if (!seenCourseIds.add(courseId)) continue;
        lessons.add(
          ResumeLesson.fromJson({
            'course_id': courseId,
            'course_title': course['title'] as String? ?? '',
            'thumbnail_url': course['thumbnail_url'] as String?,
            'lesson_id': lesson['id'] as String,
            'lesson_title': lesson['title'] as String? ?? '',
            'section_title': section?['title'] as String? ?? '',
            'last_watched': data['last_watched'] as String? ??
                DateTime.now().toIso8601String(),
            'progress_pct': (data['progress_pct'] as num?)?.toDouble() ?? 0.0,
          }),
        );
        if (lessons.length == 3) break;
      }
      return lessons;
    });
  }

  @override
  Future<List<Course>> getRecentCourses() async {
    return NetworkGuard.read(() async {
      try {
        final userId = _client.auth.currentUser?.id;
        if (userId == null) return [];

        // Use direct query instead of RPC to avoid dependency on missing database function
        final response = await _client
            .from('enrollments')
            .select('''
            progress_pct,
            completed_lessons,
            total_lessons,
            course:courses!course_id(*)
          ''')
            .eq('user_id', userId)
            // Phase 10: include 'completed' alongside 'active' — the
            // server's progress recalc flips status to 'completed' at 100%
            // while access stays entitled (active+completed), and My Courses
            // now keeps finished courses. Dropping them from this section
            // would make a just-finished course vanish from Home while still
            // sitting in /courses. Same fix as getMyCourses.
            .inFilter('status', ['active', 'completed'])
            .order('enrolled_at', ascending: false)
            .limit(5);

        return (response as List).map((enrollmentData) {
          final enrollMap = enrollmentData as Map;
          final data = Map<String, dynamic>.from(
            enrollMap['course'] as Map,
          );

          // Ensure required fields for Course entity are present
          data['tenant_id'] = data['tenant_id'] ??
              _client.auth.currentUser?.appMetadata['tenant_id'] ??
              _client.auth.currentUser?.userMetadata?['tenant_id'] ??
              '';
          data['status'] = data['status'] ?? 'published';

          // Map enrollment progress tracking into course virtual fields
          data['progress_pct'] =
              (enrollMap['progress_pct'] as num?)?.toDouble() ?? 0.0;
          data['completed_lessons'] =
              (enrollMap['completed_lessons'] as num?)?.toInt() ?? 0;
          data['total_lessons'] =
              (enrollMap['total_lessons'] as num?)?.toInt() ?? 0;

          return Course.fromJson(data);
        }).toList();
      } on PostgrestException catch (e) {
        // Was previously `throw Exception(e.message)` -- an untyped
        // Exception that ErrorHandler/AuthErrorPolicy can never classify
        // and that discarded the Postgrest error code entirely. See
        // Section 13/14 hardening pass.
        throw ServerException(e.message, e.code); // check-ignore
      } catch (e) {
        if (e is AppException) rethrow;
        debugPrint('[HomeRemoteDataSource] Mapping Error: ${e.runtimeType}');
        throw NetworkExceptionMapper.map(e);
      }
    });
  }

  @override
  Future<List<TodoItem>> getRecentTodos() async {
    return NetworkGuard.read(() async {
      try {
        final userId = _client.auth.currentUser?.id;
        if (userId == null) return [];

        // v13: Added deleted_at filter for soft delete support
        final response = await _client
            .from('todos')
            .select()
            .eq('user_id', userId)
            .eq('is_completed', false)
            .filter('deleted_at', 'is', null)
            .order('created_at', ascending: false)
            .limit(3);

        return (response as List)
            .map((json) => TodoItem.fromJson(json))
            .toList();
      } on PostgrestException catch (e) {
        throw ServerException(e.message, e.code); // check-ignore
      } catch (e) {
        if (e is AppException) rethrow;
        throw NetworkExceptionMapper.map(e);
      }
    });
  }
}
