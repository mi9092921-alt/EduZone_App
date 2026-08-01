import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/course.dart';
import '../repositories/courses_repository.dart';

class GetPublicCourses {
  final CoursesRepository repository;

  GetPublicCourses(this.repository);

  Future<Either<Failure, List<Course>>> call({
    int page = 1,
    int limit = 10,
  }) async {
    return await repository.getPublicCourses(page: page, limit: limit);
  }
}
