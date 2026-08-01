import '../../../courses/domain/entities/course.dart';
import '../../../todo/domain/entities/todo_item.dart';
import '../../domain/entities/resume_lesson.dart';

abstract class HomeRemoteDataSource {
  Future<ResumeLesson?> getResumeLesson();
  Future<List<Course>> getRecentCourses();
  Future<List<TodoItem>> getRecentTodos();
}
