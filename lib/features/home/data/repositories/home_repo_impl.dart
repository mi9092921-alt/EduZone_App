import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../../../courses/domain/entities/course.dart';
import '../../domain/entities/home_course_summary.dart';
import '../../domain/entities/home_todo_summary.dart';
import '../../domain/entities/resume_lesson.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_remote_datasource.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeRemoteDataSource remoteDataSource;

  HomeRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, ResumeLesson?>> getResumeLesson() async {
    try {
      final lesson = await remoteDataSource.getResumeLesson();
      return Right(lesson);
    } catch (e) {
      return Left(failureFromError(e));
    }
  }

  @override
  Future<Either<Failure, List<HomeCourseSummary>>> getRecentCourses() async {
    try {
      // `remoteDataSource` still returns the `courses` feature's `Course`
      // entity (via `Course.fromJson`) so we can reuse its well-tested
      // Supabase row-parsing logic instead of duplicating it here — that
      // reuse happens in the `data` layer, which is allowed to know about
      // it. We map to `HomeCourseSummary` right here, at the boundary of
      // the domain interface, so nothing above this line ever sees `Course`.
      final courses = await remoteDataSource.getRecentCourses();
      final summaries = courses
          .map(
            (c) => HomeCourseSummary(
              id: c.id,
              title: c.title,
              thumbnailUrl: c.thumbnailUrl,
              level: c.level,
              totalLessons: c.totalLessons ?? c.computedTotalLessons,
              completedLessons: c.completedLessons,
              progressPct: c.progressPct,
            ),
          )
          .toList();
      return Right(summaries);
    } catch (e) {
      return Left(failureFromError(e));
    }
  }

  @override
  Future<Either<Failure, List<HomeTodoSummary>>> getRecentTodos() async {
    try {
      final todos = await remoteDataSource.getRecentTodos();
      final summaries = todos
          .map(
            (t) => HomeTodoSummary(
              id: t.id,
              userId: t.userId,
              tenantId: t.tenantId,
              title: t.title,
              dueAt: t.dueAt,
              isCompleted: t.isCompleted,
              priority: t.priority,
            ),
          )
          .toList();
      return Right(summaries);
    } catch (e) {
      return Left(failureFromError(e));
    }
  }
}
