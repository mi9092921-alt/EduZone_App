import 'package:app/core/error/failures.dart';
import 'package:app/features/home/domain/entities/home_course_summary.dart';
import 'package:app/features/home/domain/entities/home_todo_summary.dart';
import 'package:app/features/home/domain/entities/resume_lesson.dart';
import 'package:app/features/home/domain/repositories/home_repository.dart';
import 'package:app/features/home/application/providers/home_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockHomeRepository extends Mock implements HomeRepository {}

/// Test-only provider mirroring how production code invokes the helper:
/// `invalidateHomeProviders(ref)` is only ever called from inside another
/// provider/notifier (see auth_provider.dart), never with a bare
/// ProviderContainer. Reading this provider exercises the exact same call
/// shape without relying on ProviderContainer satisfying the Ref interface.
final _invalidateHomeProvidersTestTrigger = Provider<void>((ref) {
  invalidateHomeProviders(ref);
});

void main() {
  late ProviderContainer container;
  late MockHomeRepository mockRepository;

  final tLesson = ResumeLesson(
    progressPct: 30,
    lastWatched: DateTime(2024),
    lessonId: 'l1',
    lessonTitle: 'Lesson 1',
    sectionTitle: 'Section 1',
    courseId: 'c1',
    courseTitle: 'Course 1',
  );

  final tCourses = [
    const HomeCourseSummary(
      id: 'c1',
      title: 'Course 1',
      level: 'beginner',
      totalLessons: 0,
    ),
  ];

  final tTodos = [
    const HomeTodoSummary(
      id: 't1',
      userId: 'u1',
      tenantId: 'tenant1',
      title: 'Todo 1',
    ),
  ];

  setUp(() {
    mockRepository = MockHomeRepository();
    container = ProviderContainer(
      overrides: [
        homeRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('resumeLessonProvider', () {
    test('emits the lesson when the repository call succeeds', () async {
      when(() => mockRepository.getResumeLesson())
          .thenAnswer((_) async => Right(tLesson));

      final result = await container.read(resumeLessonProvider.future);

      expect(result, tLesson);
      verify(() => mockRepository.getResumeLesson()).called(1);
    });

    test('emits null when there is no lesson to resume', () async {
      when(() => mockRepository.getResumeLesson())
          .thenAnswer((_) async => const Right(null));

      final result = await container.read(resumeLessonProvider.future);

      expect(result, isNull);
    });

    test('propagates a failure when the repository returns a Left', () async {
      when(() => mockRepository.getResumeLesson()).thenAnswer(
        (_) async => const Left(ServerFailure('resume lesson failed')),
      );

      // Riverpod's retry/dispose lifecycle may re-wrap the original error
      // before it reaches `.future`, so we only assert that failure
      // propagates (not its exact runtime type) — see the equivalent
      // pattern in player4_provider_test.dart.
      await expectLater(
        container.read(resumeLessonProvider.future),
        throwsA(anything),
      );

      verify(() => mockRepository.getResumeLesson()).called(1);
    });
  });

  group('recentCoursesProvider', () {
    test('emits the course list when the repository call succeeds', () async {
      when(() => mockRepository.getRecentCourses())
          .thenAnswer((_) async => Right(tCourses));

      final result = await container.read(recentCoursesProvider.future);

      expect(result, tCourses);
    });

    test('propagates a failure when the repository returns a Left', () async {
      when(() => mockRepository.getRecentCourses()).thenAnswer(
        (_) async => const Left(ServerFailure('courses failed')),
      );

      await expectLater(
        container.read(recentCoursesProvider.future),
        throwsA(anything),
      );
    });
  });

  group('recentTodosProvider', () {
    test('emits the todo list when the repository call succeeds', () async {
      when(() => mockRepository.getRecentTodos())
          .thenAnswer((_) async => Right(tTodos));

      final result = await container.read(recentTodosProvider.future);

      expect(result, tTodos);
    });

    test('propagates a failure when the repository returns a Left', () async {
      when(() => mockRepository.getRecentTodos()).thenAnswer(
        (_) async => const Left(ServerFailure('todos failed')),
      );

      await expectLater(
        container.read(recentTodosProvider.future),
        throwsA(anything),
      );
    });
  });

  group('invalidateHomeProviders', () {
    test('forces resumeLesson/recentCourses/recentTodos to re-fetch from '
        'the repository on next read (session/logout cleanup)', () async {
      when(() => mockRepository.getResumeLesson())
          .thenAnswer((_) async => Right(tLesson));
      when(() => mockRepository.getRecentCourses())
          .thenAnswer((_) async => Right(tCourses));
      when(() => mockRepository.getRecentTodos())
          .thenAnswer((_) async => Right(tTodos));

      // Keep these auto-dispose providers alive for the duration of the
      // test so the cached value truly comes from Riverpod's cache and
      // not from a provider that was silently re-created between reads.
      container.listen(resumeLessonProvider, (_, _) {});
      container.listen(recentCoursesProvider, (_, _) {});
      container.listen(recentTodosProvider, (_, _) {});

      // Prime all three providers once.
      await container.read(resumeLessonProvider.future);
      await container.read(recentCoursesProvider.future);
      await container.read(recentTodosProvider.future);

      verify(() => mockRepository.getResumeLesson()).called(1);
      verify(() => mockRepository.getRecentCourses()).called(1);
      verify(() => mockRepository.getRecentTodos()).called(1);

      // Simulate logout.
      container.read(_invalidateHomeProvidersTestTrigger);

      // Reading again after invalidation must hit the repository again,
      // proving stale, user-scoped data isn't leaked into the next session.
      await container.read(resumeLessonProvider.future);
      await container.read(recentCoursesProvider.future);
      await container.read(recentTodosProvider.future);

      verify(() => mockRepository.getResumeLesson()).called(1);
      verify(() => mockRepository.getRecentCourses()).called(1);
      verify(() => mockRepository.getRecentTodos()).called(1);
    });
  });
}
