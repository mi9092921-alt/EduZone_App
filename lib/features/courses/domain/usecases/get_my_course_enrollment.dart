import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/course_enrollment.dart';
import '../repositories/courses_repository.dart';

class GetMyCourseEnrollment {
  final CoursesRepository repository;

  GetMyCourseEnrollment(this.repository);

  Future<Either<Failure, CourseEnrollment?>> call(String courseId) async {
    return await repository.getMyCourseEnrollment(courseId);
  }
}
