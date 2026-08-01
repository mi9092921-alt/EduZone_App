import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/lesson_content.dart';
import '../repositories/courses_repository.dart';

class GetLessonContent {
  final CoursesRepository repository;

  GetLessonContent(this.repository);

  Future<Either<Failure, LessonContent>> call(String lessonId) async {
    return await repository.getLessonContent(lessonId);
  }
}
