import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../repositories/courses_repository.dart';

class UpdateLessonProgress {
  final CoursesRepository repository;

  UpdateLessonProgress(this.repository);

  /// Updates or inserts a progress record using an RPC or direct upsert.
  Future<Either<Failure, void>> call({
    required String courseId,
    required String lessonId,
    required bool completed,
    required double progressPct,
    int? watchTimeSec,
  }) async {
    return await repository.updateLessonProgress(
      courseId: courseId,
      lessonId: lessonId,
      completed: completed,
      progressPct: progressPct,
      watchTimeSec: watchTimeSec,
    );
  }
}
