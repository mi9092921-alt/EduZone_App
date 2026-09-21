import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/network_config.dart';
import '../../../../core/network/network_exception_mapper.dart';
import '../../../../core/network/network_guard.dart';
import '../../../../core/network/supabase_client.dart';
import '../../domain/entities/lesson_progress_sync_item.dart';

/// Remote data source for video progress operations.
///
/// Progress writes go through the `update_lesson_progress` RPC (never a
/// direct `user_progress` upsert) and activity logging through
/// `log_activity_async`.
class VideoPlayerRemoteDataSource {
  final SupabaseClient? _explicitClient;
  SupabaseClient get _client => _explicitClient ?? SupabaseService.client;

  VideoPlayerRemoteDataSource([SupabaseClient? client])
    : _explicitClient = client;

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

  /// Syncs multiple progress items by delegating each one to the
  /// server-authoritative `update_lesson_progress` RPC.
  ///
  /// PHASE-5 authorization fix: this used to be a direct
  /// `user_progress` upsert, which RLS scoped to the caller's own rows +
  /// tenant but which BYPASSED the entitlement check the platform applies
  /// to every other progress write — the RPC validates preview/enrollment/
  /// teacher/admin access for (course, lesson), derives the tenant
  /// server-side, clamps progress values, and writes the row, all inside
  /// one transaction. A direct upsert allowed any authenticated user to
  /// fabricate progress (including completions) for courses they were
  /// never entitled to. The RPC is also the path the rest of the app
  /// already uses (see `CoursesRemoteDataSourceImpl.updateLessonProgress`),
  /// so authorization logic stays in exactly one place.
  ///
  /// Items are attempted independently: a failure in one item does not
  /// prevent the remaining items from being attempted. The first failure
  /// is rethrown after the loop, and `LessonProgressSyncEngine` re-queues
  /// the whole batch — safe, because every item is an idempotent upsert,
  /// so re-sending items that already succeeded is harmless.
  Future<void> syncProgressBatch(List<LessonProgressSyncItem> items) async {
    if (items.isEmpty) return;

    return NetworkGuard.write(() async {
      try {
        final userId = _client.auth.currentUser?.id;
        if (userId == null) throw const ServerException('User not authenticated'); // check-ignore

        Object? firstError;
        StackTrace? firstStackTrace;
        for (final item in items) {
          try {
            await _client.rpc(
              'update_lesson_progress',
              params: {
                'p_course_id': item.courseId,
                'p_lesson_id': item.lessonId,
                'p_progress_pct': item.progressPct,
                'p_completed': item.completed,
                if (item.watchTimeSec != null) 'p_watch_time_sec': item.watchTimeSec,
              },
            );
          } catch (e, st) {
            firstError ??= e;
            firstStackTrace ??= st;
          }
        }

        if (firstError != null) {
          if (firstError is PostgrestException) {
            throw ServerException(firstError.message, firstError.code); // check-ignore
          }
          if (firstError is AppException) throw firstError;
          Error.throwWithStackTrace(
            NetworkExceptionMapper.map(firstError),
            firstStackTrace!,
          );
        }
      } on PostgrestException catch (e) {
        throw ServerException(e.message, e.code); // check-ignore
      } catch (e) {
        if (e is AppException) rethrow;
        throw NetworkExceptionMapper.map(e);
      }
    });
  }

  /// Logs an activity event (best-effort, never throws).
  ///
  /// Previously had no timeout -- every failure was already swallowed
  /// below, but a stalled connection doesn't fail, it hangs, so this
  /// could sit open indefinitely despite being written as fire-and-forget
  /// telemetry. See Section 13 ("Networking Reliability") of the project
  /// instructions.
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
      }).timeout(NetworkConfig.telemetryTimeout);
    } catch (_) {
      // Best-effort — ignore non-critical analytics errors
    }
  }
}
