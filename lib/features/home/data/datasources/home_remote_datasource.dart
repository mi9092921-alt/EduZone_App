import '../../../../shared/models/course.dart';
import '../../../../shared/models/todo_item.dart';
import '../../domain/entities/resume_lesson.dart';

abstract class HomeRemoteDataSource {
  Future<ResumeLesson?> getResumeLesson();
  Future<List<ResumeLesson>> getResumeLessons() async {
    final lesson = await getResumeLesson();
    return lesson == null ? [] : [lesson];
  }
  Future<List<Course>> getRecentCourses();
  Future<List<TodoItem>> getRecentTodos();
}
