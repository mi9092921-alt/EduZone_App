import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/supabase_client.dart';

/// Remote data source for video progress operations.
///
/// Handles upsert to `user_progress` table and activity logging.
class VideoPlayerRemoteDataSource {
  final SupabaseClient _client;

  VideoPlayerRemoteDataSource([SupabaseClient? client])
    : _client = client ?? SupabaseService.client;

  /// Upserts the user's progress for a specific lesson.
  Future<void> syncProgress({
    required String courseId,
    required String lessonId,
    required bool completed,
    required double progressPct,
    int? watchTimeSec,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw const ServerException('User not authenticated');

      var tenantId = _client.auth.currentUser?.appMetadata['tenant_id'] ??
          _client.auth.currentUser?.userMetadata?['tenant_id'];
      if (tenantId == null) {
        final courseData = await _client
            .from('courses')
            .select('tenant_id')
            .eq('id', courseId)
            .single();
        tenantId = courseData['tenant_id'] as String?;
      }
      if (tenantId == null) {
        throw const ServerException(
          'Could not determine tenant_id for progress update',
        );
      }

      await _client.from('user_progress').upsert({
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
      await _client.rpc('log_activity_async', params: {
        'p_user_id': userId,
        'p_type': completed ? 'lesson_completed' : 'lesson_progress',
        'p_details': {
          'course_id': courseId,
          'lesson_id': lessonId,
          'progress_pct': progressPct,
        },
      });
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  /// Logs an activity event (best-effort, never throws).
  Future<void> logActivity({
    required String eventType,
    required Map<String, dynamic> metadata,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client.rpc('log_activity_async', params: {
        'p_user_id': userId,
        'p_type': eventType,
        'p_details': metadata,
      });
    } catch (_) {
      // Best-effort — ignore non-critical analytics errors
    }
  }
}
