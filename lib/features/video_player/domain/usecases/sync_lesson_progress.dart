import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/lesson_progress_sync_item.dart';
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
    return repository.syncProgressBatch([
      LessonProgressSyncItem(
        courseId: courseId,
        lessonId: lessonId,
        completed: completed,
        progressPct: progressPct.clamp(0, 100).toDouble(),
        watchTimeSec: watchTimeSec,
      ),
    ]);
  }

  Future<Either<Failure, void>> batch(List<LessonProgressSyncItem> items) {
    if (items.isEmpty) return Future.value(const Right(null));

    return repository.syncProgressBatch(
      items
          .map(
            (item) => LessonProgressSyncItem(
              courseId: item.courseId,
              lessonId: item.lessonId,
              completed: item.completed,
              progressPct: item.progressPct.clamp(0, 100).toDouble(),
              watchTimeSec: item.watchTimeSec,
            ),
          )
          .toList(growable: false),
    );
  }
}
