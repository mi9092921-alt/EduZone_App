import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../repositories/courses_repository.dart';

class GetUserSubscribedCourseIds {
  final CoursesRepository repository;

  GetUserSubscribedCourseIds(this.repository);

  Future<Either<Failure, Set<String>>> call() async {
    return await repository.getUserSubscribedCourseIds();
  }
}
