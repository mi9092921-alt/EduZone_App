import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../repositories/video_player_repository.dart';

/// Use case for syncing lesson progress to the database.
///
/// Called by [VideoProgressNotifier] on a debounced 10-second timer
/// and immediately on lesson completion (≥ 90%).
class SyncLessonProgress {
  final VideoPlayerRepository repository;

  SyncLessonProgress(this.repository);

  Future<Either<Failure, void>> call({
    required String courseId,
    required String lessonId,
    required bool completed,
    required double progressPct,
    int? watchTimeSec,
  }) {
    return repository.syncProgress(
      courseId: courseId,
      lessonId: lessonId,
      completed: completed,
      progressPct: progressPct,
      watchTimeSec: watchTimeSec,
    );
  }
}
