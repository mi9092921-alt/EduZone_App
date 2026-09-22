import 'package:flutter/foundation.dart';
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
            // Phase 10 (poison-pill fix): the update_lesson_progress RPC
            // raises a small, closed set of business errors that can NEVER
            // succeed on retry — the lesson was deleted, the enrollment was
            // revoked, or the client sent an out-of-contract value. Re-queueing
            // such an item re-poisons every subsequent batch until the retry
            // budget exhausts, stranding the OTHER (valid) pending items too.
            // Dead-letter exactly those errors: the offending item is dropped,
            // and the loop continues. Everything else — AUTH_REQUIRED (token
            // refresh may still fix it), TENANT_CONTEXT_REQUIRED /
            // CROSS_TENANT_ACCESS_DENIED (account-state signals consumed by
            // the access-check channel), network/5xx/timeout — keeps the old
            // propagate-and-requeue behavior. (All five markers below are
            // RAISE EXCEPTIONs in update_lesson_progress itself — see
            // 07_functions.sql:1652-1690.)
            if (e is PostgrestException &&
                _isDeterministicBusinessDenial(e)) {
              debugPrint(
                '[VideoPlayerRemoteDataSource] dead-lettering progress item '
                '${item.lessonId}: ${e.message}',
              );
              continue;
            }
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

  /// Phase 10 (poison-pill fix): whether [e] is one of the closed set of
  /// business errors `update_lesson_progress` raises that are deterministic
  /// — retrying the SAME item will fail identically forever.
  ///
  /// The message must name the marker (P0001 is the generic SQLSTATE every
  /// PL/pgSQL RAISE EXCEPTION shares — see LessonAccessErrorClassifier's
  /// rationale in the courses feature for why the code alone is not
  /// sufficient).
  static bool _isDeterministicBusinessDenial(PostgrestException e) {
    const markers = [
      'LESSON_NOT_FOUND',
      'ACCESS_DENIED',
      'INVALID_PROGRESS',
      'INVALID_WATCH_TIME',
      'INVALID_PROGRESS_STATE',
    ];
    return e.code == 'P0001' &&
        markers.any((marker) => e.message.contains(marker));
  }
}
