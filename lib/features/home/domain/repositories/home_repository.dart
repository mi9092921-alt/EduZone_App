import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/home_course_summary.dart';
import '../entities/home_todo_summary.dart';
import '../entities/resume_lesson.dart';

abstract class HomeRepository {
  Future<Either<Failure, ResumeLesson?>> getResumeLesson();
  Future<Either<Failure, List<HomeCourseSummary>>> getRecentCourses();
  Future<Either<Failure, List<HomeTodoSummary>>> getRecentTodos();
}
