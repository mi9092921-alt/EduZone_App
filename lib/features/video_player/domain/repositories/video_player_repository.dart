import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';

/// Repository contract for video progress operations.
///
/// Handles syncing watch progress to the `user_progress` table
/// and logging activity events.
abstract class VideoPlayerRepository {
  /// Upserts the user's progress for a specific lesson.
  Future<Either<Failure, void>> syncProgress({
    required String courseId,
    required String lessonId,
    required bool completed,
    required double progressPct,
    int? watchTimeSec,
  });

  /// Logs an activity event (e.g. lesson_started, lesson_completed).
  Future<void> logActivity({
    required String eventType,
    required Map<String, dynamic> metadata,
  });
}
