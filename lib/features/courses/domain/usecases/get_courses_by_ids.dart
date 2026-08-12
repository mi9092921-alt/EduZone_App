import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/course.dart';
import '../repositories/courses_repository.dart';

class GetCoursesByIds {
  final CoursesRepository repository;

  GetCoursesByIds(this.repository);

  Future<Either<Failure, List<Course>>> call(List<String> ids) async {
    return await repository.getCoursesByIds(ids);
  }
}
