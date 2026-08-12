import 'package:app/core/error/failures.dart';
import 'package:app/features/courses/domain/entities/course.dart';
import 'package:app/features/home/data/datasources/home_remote_datasource.dart';
import 'package:app/features/home/data/repositories/home_repo_impl.dart';
import 'package:app/features/home/domain/entities/home_course_summary.dart';
import 'package:app/features/home/domain/entities/home_todo_summary.dart';
import 'package:app/features/home/domain/entities/resume_lesson.dart';
import 'package:app/features/todo/domain/entities/todo_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockHomeRemoteDataSource extends Mock implements HomeRemoteDataSource {}

void main() {
  late HomeRepositoryImpl repository;
  late MockHomeRemoteDataSource mockDataSource;

  setUp(() {
    mockDataSource = MockHomeRemoteDataSource();
    repository = HomeRepositoryImpl(mockDataSource);
  });

  group('getResumeLesson', () {
    final tLesson = ResumeLesson(
      courseId: 'c1',
      lessonId: 'l1',
      courseTitle: 'Course 1',
      sectionTitle: 'Section 1',
      lessonTitle: 'Lesson 1',
      progressPct: 50.0,
      thumbnailUrl: 'url',
      lastWatched: DateTime(2023),
    );

    test('should return Right(lesson) when data source succeeds', () async {
      when(
        () => mockDataSource.getResumeLesson(),
      ).thenAnswer((_) async => tLesson);

      final result = await repository.getResumeLesson();

      expect(result, isA<Right<Failure, ResumeLesson?>>());
      expect(result.getOrElse((_) => null), equals(tLesson));
    });

    test('should return Left(ServerFailure) on PostgrestException', () async {
      when(
        () => mockDataSource.getResumeLesson(),
      ).thenThrow(const PostgrestException(message: 'Database error'));

      final result = await repository.getResumeLesson();

      expect(result, isA<Left<Failure, ResumeLesson?>>());
      result.fold(
        (l) => expect(l.message, 'Database error'),
        (r) => fail('Should have returned Left'),
      );
    });

    test('should return Left(ServerFailure) on general exception', () async {
      when(
        () => mockDataSource.getResumeLesson(),
      ).thenThrow(Exception('General error'));

      final result = await repository.getResumeLesson();

      expect(result, isA<Left<Failure, ResumeLesson?>>());
    });
  });

  group('getRecentCourses', () {
    final tCourses = [
      const Course(
        id: 'c1',
        tenantId: 't1',
        title: 'Course 1',
        status: 'published',
        isFeatured: true,
        totalLessons: 10,
      ),
    ];

    // What HomeRepositoryImpl is expected to map the above `Course` into —
    // this is the actual domain-facing contract after ARCH-004 (home's
    // domain layer no longer sees `Course` directly, only this summary).
    const tExpectedSummaries = [
      HomeCourseSummary(
        id: 'c1',
        title: 'Course 1',
        level: 'beginner',
        totalLessons: 10,
      ),
    ];

    test('should return Right(courses) when data source succeeds', () async {
      when(
        () => mockDataSource.getRecentCourses(),
      ).thenAnswer((_) async => tCourses);

      final result = await repository.getRecentCourses();

      expect(result.getOrElse((_) => []), equals(tExpectedSummaries));
    });

    test('should return Left(ServerFailure) on error', () async {
      when(
        () => mockDataSource.getRecentCourses(),
      ).thenThrow(Exception('Error'));

      final result = await repository.getRecentCourses();

      expect(result, isA<Left<Failure, List<HomeCourseSummary>>>());
    });
  });

  group('getRecentTodos', () {
    final List<TodoItem> tTodos = [
      TodoItem(
        id: 't1',
        title: 'Todo 1',
        createdAt: DateTime.now(),
        userId: 'u1',
        tenantId: 'tenant1',
      ),
    ];

    // Expected mapping into HomeTodoSummary — note `createdAt` is
    // intentionally dropped: HomeTodoSummary doesn't carry it (it isn't
    // used anywhere in the home dashboard UI).
    const tExpectedSummaries = [
      HomeTodoSummary(
        id: 't1',
        userId: 'u1',
        tenantId: 'tenant1',
        title: 'Todo 1',
      ),
    ];

    test('should return Right(todos) when data source succeeds', () async {
      when(
        () => mockDataSource.getRecentTodos(),
      ).thenAnswer((_) async => tTodos);

      final result = await repository.getRecentTodos();

      expect(result.getOrElse((_) => []), equals(tExpectedSummaries));
    });

    test('should return Left(ServerFailure) on error', () async {
      when(() => mockDataSource.getRecentTodos()).thenThrow(Exception('Error'));

      final result = await repository.getRecentTodos();

      expect(result, isA<Left<Failure, List<HomeTodoSummary>>>());
    });
  });
}
