import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/network_exception_mapper.dart';
import '../../../../core/network/network_guard.dart';
import '../../../../core/network/supabase_client.dart';
import '../../domain/entities/lesson_progress_sync_item.dart';

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
    return syncProgressBatch([
      LessonProgressSyncItem(
        courseId: courseId,
        lessonId: lessonId,
        completed: completed,
        progressPct: progressPct,
        watchTimeSec: watchTimeSec,
      ),
    ]);
  }

  /// Upserts multiple progress rows in one PostgREST request.
  Future<void> syncProgressBatch(List<LessonProgressSyncItem> items) async {
    if (items.isEmpty) return;

    return NetworkGuard.write(() async {
      try {
        final userId = _client.auth.currentUser?.id;
        if (userId == null) throw const ServerException('User not authenticated'); // check-ignore

        final tenantId = await _resolveTenantId(items);
        final now = DateTime.timestamp().toIso8601String();
        final rows = items
            .map(
              (item) => {
                'user_id': userId,
                'course_id': item.courseId,
                'lesson_id': item.lessonId,
                'tenant_id': tenantId,
                'completed': item.completed,
                'progress_pct': item.progressPct,
                if (item.completed) 'completed_at': now,
                if (item.watchTimeSec != null) 'watch_time_sec': item.watchTimeSec,
                'last_watched': now,
              },
            )
            .toList(growable: false);

        await _client.from('user_progress').upsert(
              rows,
              onConflict: 'user_id,course_id,lesson_id',
            );
      } on PostgrestException catch (e) {
        throw ServerException(e.message, e.code); // check-ignore
      } catch (e) {
        if (e is AppException) rethrow;
        throw NetworkExceptionMapper.map(e);
      }
    });
  }

  Future<dynamic> _resolveTenantId(List<LessonProgressSyncItem> items) async {
    final jwtTenantId = _client.auth.currentUser?.appMetadata['tenant_id'] ??
        _client.auth.currentUser?.userMetadata?['tenant_id'];
    if (jwtTenantId != null) return jwtTenantId;

    final courseData = await _client
        .from('courses')
        .select('tenant_id')
        .eq('id', items.first.courseId)
        .single();
    final tenantId = courseData['tenant_id'];
    if (tenantId == null) {
      throw const ServerException(
        'Could not determine tenant_id for progress update', // check-ignore
      );
    }

    return tenantId;
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
