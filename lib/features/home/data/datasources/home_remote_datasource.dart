import '../../../../shared/models/course.dart';
import '../../../../shared/models/todo_item.dart';
import '../../domain/entities/resume_lesson.dart';

abstract class HomeRemoteDataSource {
  // Phase 10: the single-lesson `getResumeLesson()` variant was deleted —
  // it had zero production watchers, swallowed every failure to `null`, and
  // (unlike `getResumeLessons`) applied NO active-enrollment filter, so
  // rewiring it would have surfaced lessons from revoked courses.
  Future<List<ResumeLesson>> getResumeLessons();
  Future<List<Course>> getRecentCourses();
  Future<List<TodoItem>> getRecentTodos();
}
