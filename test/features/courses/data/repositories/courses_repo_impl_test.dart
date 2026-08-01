import 'package:app/core/error/exceptions.dart';
import 'package:app/core/error/failures.dart';
import 'package:app/core/services/storage_service.dart';
import 'package:app/features/courses/data/datasources/courses_remote_ds.dart';
import 'package:app/features/courses/data/repositories/courses_repo_impl.dart';
import 'package:app/features/courses/domain/entities/course.dart';
import 'package:app/features/courses/domain/entities/course_enrollment.dart';
import 'package:app/features/courses/domain/entities/course_progress_summary.dart';
import 'package:app/features/courses/domain/entities/lesson_content.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockCoursesRemoteDataSource extends Mock
    implements CoursesRemoteDataSource {}

class MockStorageService extends Mock implements StorageService {}

void main() {
  late CoursesRepositoryImpl repository;
  late MockCoursesRemoteDataSource mockDataSource;
  late MockStorageService mockStorageService;

  const tUserId = 'user-1';

  setUp(() {
    mockDataSource = MockCoursesRemoteDataSource();
    mockStorageService = MockStorageService();
    // currentUserIdProvider is injected so bookmark tests don't depend on
    // a real Supabase session (see courses_repo_impl.dart).
    repository = CoursesRepositoryImpl(
      mockDataSource,
      mockStorageService,
      currentUserIdProvider: () => tUserId,
    );
  });

  const tCourse = Course(
    id: 'c1',
    tenantId: 't1',
    title: 'Course',
    status: 'published',
  );

  group('getCourseDetails', () {
    test('should return Right(Course) when data source succeeds', () async {
      when(
        () => mockDataSource.getCourseDetails('c1'),
      ).thenAnswer((_) async => tCourse);

      final result = await repository.getCourseDetails('c1');

      expect(result.getOrElse((_) => throw Exception()), equals(tCourse));
    });

    test('should return Left(ServerFailure) on exception', () async {
      when(
        () => mockDataSource.getCourseDetails('c1'),
      ).thenThrow(const ServerException('Failed'));

      final result = await repository.getCourseDetails('c1');

      expect(result, isA<Left<Failure, Course>>());
      result.fold(
        (l) => expect(l.message, 'Failed'),
        (r) => fail('Should have returned Left'),
      );
    });
  });

  group('getPublicCourses', () {
    final tCourses = [tCourse];

    test(
      'should return Right(List<Course>) when data source succeeds',
      () async {
        when(
          () => mockDataSource.getPublicCourses(page: 1, limit: 10),
        ).thenAnswer((_) async => tCourses);

        final result = await repository.getPublicCourses();

        expect(result.getOrElse((_) => throw Exception()), equals(tCourses));
      },
    );

    test('should return Left(ServerFailure) on exception', () async {
      when(
        () => mockDataSource.getPublicCourses(page: 1, limit: 10),
      ).thenThrow(const ServerException('Failed'));

      final result = await repository.getPublicCourses();

      expect(result, isA<Left<Failure, List<Course>>>());
    });
  });

  group('getMyCourses', () {
    final tEnrollments = [
      const CourseEnrollment(
          id: 'e1', userId: tUserId, courseId: 'c1', tenantId: 't1'),
    ];

    test('should return Right(List<CourseEnrollment>) on success', () async {
      when(() => mockDataSource.getMyCourses())
          .thenAnswer((_) async => tEnrollments);

      final result = await repository.getMyCourses();

      expect(result.getOrElse((_) => throw Exception()), equals(tEnrollments));
    });

    test('should return Left(ServerFailure) on exception', () async {
      when(() => mockDataSource.getMyCourses())
          .thenThrow(const ServerException('Failed'));

      final result = await repository.getMyCourses();

      expect(result, isA<Left<Failure, List<CourseEnrollment>>>());
    });
  });

  group('getCourseOutline', () {
    test('should return Right(Course) on success', () async {
      when(() => mockDataSource.getCourseOutline('c1'))
          .thenAnswer((_) async => tCourse);

      final result = await repository.getCourseOutline('c1');

      expect(result.getOrElse((_) => throw Exception()), equals(tCourse));
    });

    test('should return Left(ServerFailure) on exception', () async {
      when(() => mockDataSource.getCourseOutline('c1'))
          .thenThrow(const ServerException('Failed'));

      final result = await repository.getCourseOutline('c1');

      expect(result, isA<Left<Failure, Course>>());
    });
  });

  group('getMyCourseEnrollment', () {
    const tEnrollment = CourseEnrollment(
        id: 'e1', userId: tUserId, courseId: 'c1', tenantId: 't1');

    test('should return Right(CourseEnrollment) when enrolled', () async {
      when(() => mockDataSource.getMyCourseEnrollment('c1'))
          .thenAnswer((_) async => tEnrollment);

      final result = await repository.getMyCourseEnrollment('c1');

      expect(result.getOrElse((_) => throw Exception()), equals(tEnrollment));
    });

    test('should return Right(null) when not enrolled', () async {
      when(() => mockDataSource.getMyCourseEnrollment('c1'))
          .thenAnswer((_) async => null);

      final result = await repository.getMyCourseEnrollment('c1');

      expect(result.getOrElse((_) => throw Exception()), isNull);
    });

    test('should return Left(ServerFailure) on exception', () async {
      when(() => mockDataSource.getMyCourseEnrollment('c1'))
          .thenThrow(const ServerException('Failed'));

      final result = await repository.getMyCourseEnrollment('c1');

      expect(result, isA<Left<Failure, CourseEnrollment?>>());
    });
  });

  group('updateLessonProgress', () {
    test('should return Right(null) on success', () async {
      when(() => mockDataSource.updateLessonProgress(
            courseId: 'c1',
            lessonId: 'l1',
            completed: true,
            progressPct: 100,
            watchTimeSec: 120,
          )).thenAnswer((_) async {});

      final result = await repository.updateLessonProgress(
        courseId: 'c1',
        lessonId: 'l1',
        completed: true,
        progressPct: 100,
        watchTimeSec: 120,
      );

      expect(result, const Right(null));
    });

    test('should return Left(ServerFailure) on exception', () async {
      when(() => mockDataSource.updateLessonProgress(
            courseId: 'c1',
            lessonId: 'l1',
            completed: true,
            progressPct: 100,
          )).thenThrow(const ServerException('Failed'));

      final result = await repository.updateLessonProgress(
        courseId: 'c1',
        lessonId: 'l1',
        completed: true,
        progressPct: 100,
      );

      expect(result, isA<Left<Failure, void>>());
    });
  });

  group('getUserSubscribedCourseIds', () {
    test('should return Right(Set<String>) on success', () async {
      when(() => mockDataSource.getUserSubscribedCourseIds())
          .thenAnswer((_) async => {'c1', 'c2'});

      final result = await repository.getUserSubscribedCourseIds();

      expect(result.getOrElse((_) => throw Exception()), {'c1', 'c2'});
    });

    test('should return Left(ServerFailure) on exception', () async {
      when(() => mockDataSource.getUserSubscribedCourseIds())
          .thenThrow(const ServerException('Failed'));

      final result = await repository.getUserSubscribedCourseIds();

      expect(result, isA<Left<Failure, Set<String>>>());
    });
  });

  group('enrollInCourse', () {
    test('should return Right(null) on success', () async {
      when(() => mockDataSource.enrollInCourse('c1')).thenAnswer((_) async {});

      final result = await repository.enrollInCourse('c1');

      expect(result, const Right(null));
      verify(() => mockDataSource.enrollInCourse('c1')).called(1);
    });

    test('should return Left(ServerFailure) on exception', () async {
      when(() => mockDataSource.enrollInCourse('c1'))
          .thenThrow(const ServerException('Failed'));

      final result = await repository.enrollInCourse('c1');

      expect(result, isA<Left<Failure, void>>());
    });
  });

  group('getLessonContent', () {
    const tContent = LessonContent(
      lessonId: 'l1',
      courseId: 'c1',
      hasAccess: true,
    );

    test('should return Right(LessonContent) on success', () async {
      when(() => mockDataSource.getLessonContent('l1'))
          .thenAnswer((_) async => tContent);

      final result = await repository.getLessonContent('l1');

      expect(result.getOrElse((_) => throw Exception()), equals(tContent));
    });

    test('should return Left(ServerFailure) on exception', () async {
      when(() => mockDataSource.getLessonContent('l1'))
          .thenThrow(const ServerException('Not authorized'));

      final result = await repository.getLessonContent('l1');

      expect(result, isA<Left<Failure, LessonContent>>());
    });
  });

  group('getCourseProgressSummary', () {
    const tSummary = CourseProgressSummary(
      courseId: 'c1',
      enrolledCount: 10,
      avgProgress: 55.0,
      completedCount: 2,
    );

    test('should return Right(CourseProgressSummary) on success', () async {
      when(() => mockDataSource.getCourseProgressSummary('c1'))
          .thenAnswer((_) async => tSummary);

      final result = await repository.getCourseProgressSummary('c1');

      expect(result.getOrElse((_) => throw Exception()), equals(tSummary));
    });

    test('should return Left(ServerFailure) on exception', () async {
      when(() => mockDataSource.getCourseProgressSummary('c1'))
          .thenThrow(const ServerException('Failed'));

      final result = await repository.getCourseProgressSummary('c1');

      expect(result, isA<Left<Failure, CourseProgressSummary>>());
    });
  });

  group('getCoursesByIds', () {
    test(
      'should return Right([]) without calling the data source '
      'when ids is empty',
      () async {
        final result = await repository.getCoursesByIds(const []);

        expect(result.getOrElse((_) => throw Exception()), isEmpty);
        verifyNever(() => mockDataSource.getCoursesByIds(any()));
      },
    );

    test('should return Right(List<Course>) on success', () async {
      when(() => mockDataSource.getCoursesByIds(['c1']))
          .thenAnswer((_) async => [tCourse]);

      final result = await repository.getCoursesByIds(['c1']);

      expect(result.getOrElse((_) => throw Exception()), [tCourse]);
    });

    test('should return Left(ServerFailure) on exception', () async {
      when(() => mockDataSource.getCoursesByIds(['c1']))
          .thenThrow(const ServerException('Failed'));

      final result = await repository.getCoursesByIds(['c1']);

      expect(result, isA<Left<Failure, List<Course>>>());
    });
  });

  // ─── Bookmarks (device-local, user-scoped) ─────────────────────────────
  //
  // These rely on the injected `currentUserIdProvider` above rather than a
  // real Supabase session (see courses_repo_impl.dart), which is what
  // makes them unit-testable at all.

  group('getBookmarkedCourseIds', () {
    test(
      'should return Right(Set<String>) from storage for current user',
      () async {
        when(() => mockStorageService.getBookmarkedCourseIds(tUserId))
            .thenAnswer((_) async => ['c1', 'c2']);

        final result = await repository.getBookmarkedCourseIds();

        expect(result.getOrElse((_) => throw Exception()), {'c1', 'c2'});
      },
    );

    test(
      'should return Right(empty set) when there is no current user',
      () async {
        final repoWithNoUser = CoursesRepositoryImpl(
          mockDataSource,
          mockStorageService,
          currentUserIdProvider: () => null,
        );

        final result = await repoWithNoUser.getBookmarkedCourseIds();

        expect(result.getOrElse((_) => throw Exception()), isEmpty);
        verifyNever(() => mockStorageService.getBookmarkedCourseIds(any()));
      },
    );

    test('should return Left(CacheFailure) when storage throws', () async {
      when(() => mockStorageService.getBookmarkedCourseIds(tUserId))
          .thenThrow(Exception('disk error'));

      final result = await repository.getBookmarkedCourseIds();

      expect(result, isA<Left<Failure, Set<String>>>());
      result.fold(
        (l) => expect(l, isA<CacheFailure>()),
        (r) => fail('Should have returned Left'),
      );
    });
  });

  group('bookmarkCourse', () {
    test('should return Right(null) on success', () async {
      when(() => mockStorageService.bookmarkCourse(tUserId, 'c1'))
          .thenAnswer((_) async {});

      final result = await repository.bookmarkCourse('c1');

      expect(result, const Right(null));
    });

    test(
      'should return Left(CacheFailure) when there is no current user',
      () async {
        final repoWithNoUser = CoursesRepositoryImpl(
          mockDataSource,
          mockStorageService,
          currentUserIdProvider: () => null,
        );

        final result = await repoWithNoUser.bookmarkCourse('c1');

        expect(result, isA<Left<Failure, void>>());
        verifyNever(() => mockStorageService.bookmarkCourse(any(), any()));
      },
    );

    test('should return Left(CacheFailure) when storage throws', () async {
      when(() => mockStorageService.bookmarkCourse(tUserId, 'c1'))
          .thenThrow(Exception('disk error'));

      final result = await repository.bookmarkCourse('c1');

      expect(result, isA<Left<Failure, void>>());
    });
  });

  group('unbookmarkCourse', () {
    test('should return Right(null) on success', () async {
      when(() => mockStorageService.unbookmarkCourse(tUserId, 'c1'))
          .thenAnswer((_) async {});

      final result = await repository.unbookmarkCourse('c1');

      expect(result, const Right(null));
    });

    test(
      'should return Left(CacheFailure) when there is no current user',
      () async {
        final repoWithNoUser = CoursesRepositoryImpl(
          mockDataSource,
          mockStorageService,
          currentUserIdProvider: () => null,
        );

        final result = await repoWithNoUser.unbookmarkCourse('c1');

        expect(result, isA<Left<Failure, void>>());
        verifyNever(() => mockStorageService.unbookmarkCourse(any(), any()));
      },
    );

    test('should return Left(CacheFailure) when storage throws', () async {
      when(() => mockStorageService.unbookmarkCourse(tUserId, 'c1'))
          .thenThrow(Exception('disk error'));

      final result = await repository.unbookmarkCourse('c1');

      expect(result, isA<Left<Failure, void>>());
    });
  });
}
