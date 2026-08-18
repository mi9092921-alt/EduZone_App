import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/lesson_progress_sync_item.dart';
import '../../domain/repositories/video_player_repository.dart';
import '../datasources/video_player_remote_ds.dart';

/// Implementation of [VideoPlayerRepository].
///
/// Wraps [VideoPlayerRemoteDataSource] calls in try/catch
/// and maps exceptions to typed [Failure] objects.
class VideoPlayerRepositoryImpl implements VideoPlayerRepository {
  final VideoPlayerRemoteDataSource remoteDataSource;

  VideoPlayerRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, void>> syncProgress({
    required String courseId,
    required String lessonId,
    required bool completed,
    required double progressPct,
    int? watchTimeSec,
  }) async {
    try {
      return await syncProgressBatch([
        LessonProgressSyncItem(
          courseId: courseId,
          lessonId: lessonId,
          completed: completed,
          progressPct: progressPct,
          watchTimeSec: watchTimeSec,
        ),
      ]);
    } catch (e) {
      return Left(failureFromError(e));
    }
  }

  @override
  Future<Either<Failure, void>> syncProgressBatch(
    List<LessonProgressSyncItem> items,
  ) async {
    try {
      await remoteDataSource.syncProgressBatch(items);
      return const Right(null);
    } catch (e) {
      return Left(failureFromError(e));
    }
  }

  @override
  Future<void> logActivity({
    required String eventType,
    required Map<String, dynamic> metadata,
  }) {
    return remoteDataSource.logActivity(
      eventType: eventType,
      metadata: metadata,
    );
  }
}
