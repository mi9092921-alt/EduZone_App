import 'package:fpdart/fpdart.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
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
      await remoteDataSource.syncProgress(
        courseId: courseId,
        lessonId: lessonId,
        completed: completed,
        progressPct: progressPct,
        watchTimeSec: watchTimeSec,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
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
