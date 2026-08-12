import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../repositories/courses_repository.dart';

class GetBookmarkedCourseIds {
  final CoursesRepository repository;

  GetBookmarkedCourseIds(this.repository);

  Future<Either<Failure, Set<String>>> call() async {
    return await repository.getBookmarkedCourseIds();
  }
}
