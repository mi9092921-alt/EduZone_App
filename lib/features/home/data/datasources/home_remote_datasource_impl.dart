import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/network_exception_mapper.dart';
import '../../../../core/network/network_guard.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../shared/utils/global_error_handler.dart';
import '../../../courses/domain/entities/course.dart';
import '../../../todo/domain/entities/todo_item.dart';
import '../../domain/entities/resume_lesson.dart';
import 'home_remote_datasource.dart';

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final SupabaseClient _client;

  HomeRemoteDataSourceImpl({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  @override
  Future<ResumeLesson?> getResumeLesson() async {
    // Deliberately degrades to `null` (home just hides the resume card)
    // instead of throwing on ANY failure -- including now-classified
    // network failures. This is a pre-existing, reasonable UX choice for
    // a non-critical enrichment widget on the home screen and is kept
    // unchanged; only the underlying call now has a bounded timeout so a
    // stalled connection can no longer hang this indefinitely.
    try {
      return await NetworkGuard.read(() async {
        final userId = _client.auth.currentUser?.id;
        if (userId == null) return null;

        // Use direct query instead of RPC to avoid dependency on missing database function
        final response = await _client
            .from('user_progress')
            .select('''
            lesson_id,
            completed,
            progress_pct,
            last_watched,
            course:courses(id, title, thumbnail_url),
            lesson:lessons(id, title, section_id, section:sections(title))
          ''')
            .eq('user_id', userId)
            .eq('completed', false)
            .order('last_watched', ascending: false)
            .limit(1)
            .maybeSingle();

        if (response == null) return null;

        final data = Map<String, dynamic>.from(response as Map);

        // Map the nested structure to ResumeLesson format
        final course = data['course'] as Map?;
        final lesson = data['lesson'] as Map?;
        final section = lesson?['section'] as Map?;

        if (course == null || lesson == null) return null;

        // Build JSON with snake_case keys to match @JsonKey annotations
        final json = {
          'course_id': course['id'] as String,
          'course_title': course['title'] as String? ?? '',
          'thumbnail_url': course['thumbnail_url'] as String?,
          'lesson_id': lesson['id'] as String,
          'lesson_title': lesson['title'] as String? ?? '',
          'section_title': section?['title'] as String? ?? '',
          'last_watched': data['last_watched'] != null
              ? DateTime.parse(data['last_watched'] as String)
              : DateTime.now(),
          'progress_pct': (data['progress_pct'] as num?)?.toDouble() ?? 0.0,
        };

        return ResumeLesson.fromJson(json);
      });
    } catch (e, stack) {
      // Section 15: `debugPrint` is NOT release-gated in this codebase
      // (see GlobalErrorHandler.logError's doc comment) — a raw
      // `debugPrint('Stack: $stack')` here printed the full stack trace
      // unconditionally in every build, including release, while also
      // giving this failure zero Sentry/observability visibility (the
      // resume-lesson card would just silently disappear from Home with
      // no diagnostic record anywhere). Routing through
      // GlobalErrorHandler.logError matches every other datasource in
      // this codebase: safe exception-type-only console output in
      // release, full detail gated to kDebugMode, and forwarded to
      // Sentry either way.
      GlobalErrorHandler.logError(e, stack);
      return null;
    }
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
            .eq('status', 'active')
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
