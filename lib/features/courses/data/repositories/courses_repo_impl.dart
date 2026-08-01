import 'package:fpdart/fpdart.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/course_enrollment.dart';
import '../../domain/entities/course_progress_summary.dart';
import '../../domain/entities/lesson_content.dart';
import '../../domain/repositories/courses_repository.dart';
import '../datasources/courses_remote_ds.dart';

class CoursesRepositoryImpl implements CoursesRepository {
  final CoursesRemoteDataSource remoteDataSource;
  final StorageService _storageService;

  /// Returns the current user id. Defaults to reading it from the global
  /// [SupabaseService] singleton, but can be overridden (e.g. in tests)
  /// so this repository doesn't require a real Supabase session to unit
  /// test the bookmark methods below.
  final String? Function() _currentUserIdProvider;

  CoursesRepositoryImpl(
    this.remoteDataSource,
    this._storageService, {
    String? Function()? currentUserIdProvider,
  }) : _currentUserIdProvider = currentUserIdProvider ??
            (() => SupabaseService.client.auth.currentUser?.id);

  @override
  Future<Either<Failure, List<CourseEnrollment>>> getMyCourses() async {
    try {
      final enrollments = await remoteDataSource.getMyCourses();
      return Right(enrollments);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Course>> getCourseDetails(String courseId) async {
    try {
      final course = await remoteDataSource.getCourseDetails(courseId);
      return Right(course);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Course>> getCourseOutline(String courseId) async {
    try {
      final course = await remoteDataSource.getCourseOutline(courseId);
      return Right(course);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CourseEnrollment?>> getMyCourseEnrollment(String courseId) async {
    try {
      final result = await remoteDataSource.getMyCourseEnrollment(courseId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateLessonProgress({
    required String courseId,
    required String lessonId,
    required bool completed,
    required double progressPct,
    int? watchTimeSec,
  }) async {
    try {
      await remoteDataSource.updateLessonProgress(
        courseId: courseId,
        lessonId: lessonId,
        completed: completed,
        progressPct: progressPct,
        watchTimeSec: watchTimeSec,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Course>>> getPublicCourses({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final courses = await remoteDataSource.getPublicCourses(
        page: page,
        limit: limit,
      );
      return Right(courses);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Set<String>>> getUserSubscribedCourseIds() async {
    try {
      final ids = await remoteDataSource.getUserSubscribedCourseIds();
      return Right(ids);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> enrollInCourse(String courseId) async {
    try {
      await remoteDataSource.enrollInCourse(courseId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LessonContent>> getLessonContent(
      String lessonId) async {
    try {
      final content = await remoteDataSource.getLessonContent(lessonId);
      return Right(content);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CourseProgressSummary>> getCourseProgressSummary(
      String courseId) async {
    try {
      final summary =
          await remoteDataSource.getCourseProgressSummary(courseId);
      return Right(summary);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ─── Bookmarks (device-local, user-scoped) ────────────────────────────────

  String? get _currentUserId => _currentUserIdProvider();

  @override
  Future<Either<Failure, Set<String>>> getBookmarkedCourseIds() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return const Right(<String>{});
      final ids = await _storageService.getBookmarkedCourseIds(userId);
      return Right(ids.toSet());
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> bookmarkCourse(String courseId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return const Left(CacheFailure('No authenticated user'));
      await _storageService.bookmarkCourse(userId, courseId);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> unbookmarkCourse(String courseId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return const Left(CacheFailure('No authenticated user'));
      await _storageService.unbookmarkCourse(userId, courseId);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Course>>> getCoursesByIds(List<String> ids) async {
    try {
      if (ids.isEmpty) return const Right([]);
      final courses = await remoteDataSource.getCoursesByIds(ids);
      return Right(courses);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
