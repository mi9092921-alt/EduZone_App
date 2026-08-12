import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/course_progress_summary.dart';
import '../repositories/courses_repository.dart';

class GetCourseProgressSummary {
  final CoursesRepository repository;

  GetCourseProgressSummary(this.repository);

  Future<Either<Failure, CourseProgressSummary>> call(String courseId) async {
    return await repository.getCourseProgressSummary(courseId);
  }
}
