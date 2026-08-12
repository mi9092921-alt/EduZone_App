import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/course.dart';
import '../repositories/courses_repository.dart';

class GetCourseDetails {
  final CoursesRepository repository;

  GetCourseDetails(this.repository);

  Future<Either<Failure, Course>> call(String courseId) async {
    return await repository.getCourseDetails(courseId);
  }
}
