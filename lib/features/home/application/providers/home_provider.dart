import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failures.dart';

import '../../data/datasources/home_remote_datasource_impl.dart';
import '../../data/repositories/home_repo_impl.dart';
import '../../domain/entities/home_course_summary.dart';
import '../../domain/entities/home_todo_summary.dart';
import '../../domain/entities/resume_lesson.dart';
import '../../domain/repositories/home_repository.dart';

part 'home_provider.g.dart';

@riverpod
HomeRemoteDataSourceImpl homeRemoteDataSource(Ref ref) {
  return HomeRemoteDataSourceImpl();
}

@riverpod
HomeRepository homeRepository(Ref ref) {
  final dataSource = ref.watch(homeRemoteDataSourceProvider);
  return HomeRepositoryImpl(dataSource);
}

@riverpod
Future<ResumeLesson?> resumeLesson(Ref ref) async {
  final repository = ref.watch(homeRepositoryProvider);
  final result = await repository.getResumeLesson();
  return result.fold(
    (failure) => throw failure.toAppException(),
    (lesson) => lesson,
  );
}

@riverpod
Future<List<HomeCourseSummary>> recentCourses(Ref ref) async {
  final repository = ref.watch(homeRepositoryProvider);
  final result = await repository.getRecentCourses();
  return result.fold(
    (failure) => throw failure.toAppException(),
    (courses) => courses,
  );
}

@riverpod
Future<List<HomeTodoSummary>> recentTodos(Ref ref) async {
  final repository = ref.watch(homeRepositoryProvider);
  final result = await repository.getRecentTodos();
  return result.fold(
    (failure) => throw failure.toAppException(),
    (todos) => todos,
  );
}

// ─── Session cleanup ─────────────────────────────────────────────────────────

/// Invalidates every user-scoped provider owned by the `home` feature.
/// Called by [Auth.logout]. When you add a new user-scoped provider to this
/// file, add it here too.
void invalidateHomeProviders(Ref ref) {
  ref.invalidate(resumeLessonProvider);
  ref.invalidate(recentCoursesProvider);
  ref.invalidate(recentTodosProvider);
  ref.invalidate(homeRemoteDataSourceProvider);
}