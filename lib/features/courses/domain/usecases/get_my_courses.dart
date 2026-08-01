import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/course_enrollment.dart';
import '../repositories/courses_repository.dart';

class GetMyCourses {
  final CoursesRepository repository;

  GetMyCourses(this.repository);

  Future<Either<Failure, List<CourseEnrollment>>> call() async {
    return await repository.getMyCourses();
  }
}
