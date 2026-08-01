import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/course.dart';
import '../entities/course_enrollment.dart';
import '../entities/course_progress_summary.dart';
import '../entities/lesson_content.dart';

abstract class CoursesRepository {
  /// Fetch the current user's course enrollments, joining course details
  /// and overall progress.
  Future<Either<Failure, List<CourseEnrollment>>> getMyCourses();

  /// Fetch full details for a course (sections + lessons + user progress).
  ///
  /// v11: internally calls `get_course_outline` RPC which never exposes
  /// video URLs — safe for enrolled and unenrolled users alike.
  Future<Either<Failure, Course>> getCourseDetails(String courseId);

  /// Fetch the course outline (sections + lesson titles) using the
  /// `get_course_outline` RPC — no video URLs included.
  ///
  /// Suitable for public course-preview screens before enrollment.
  Future<Either<Failure, Course>> getCourseOutline(String courseId);

  /// Upserts the current user's progress for a specific lesson.
  Future<Either<Failure, CourseEnrollment?>> getMyCourseEnrollment(String courseId);
  Future<Either<Failure, void>> updateLessonProgress({
    required String courseId,
    required String lessonId,
    required bool completed,
    required double progressPct,
    int? watchTimeSec,
  });

  /// Fetch all public courses with optional pagination.
  Future<Either<Failure, List<Course>>> getPublicCourses({
    int page = 1,
    int limit = 10,
  });

  /// Fetch the set of course IDs the current user is enrolled in.
  Future<Either<Failure, Set<String>>> getUserSubscribedCourseIds();

  /// Enrolls the user in a specific course.
  Future<Either<Failure, void>> enrollInCourse(String courseId);

  /// Fetches video content for a lesson via the `get_lesson_content` RPC.
  ///
  /// The RPC enforces:
  ///   - Active enrollment OR `is_preview = true`
  ///   - Access logging in `lesson_access_log`
  ///
  /// Returns [LessonContent] with an opaque [videoPath] on success,
  /// or a [Failure] if the user is not authorized.
  Future<Either<Failure, LessonContent>> getLessonContent(String lessonId);

  /// Fetches aggregated progress summary for a course via RPC.
  Future<Either<Failure, CourseProgressSummary>> getCourseProgressSummary(
      String courseId);

  // ─── Bookmarks (device-local, user-scoped) ────────────────────────────────

  /// Returns the set of course IDs bookmarked by the current user.
  Future<Either<Failure, Set<String>>> getBookmarkedCourseIds();

  /// Adds a bookmark for [courseId] on this device.
  Future<Either<Failure, void>> bookmarkCourse(String courseId);

  /// Removes the bookmark for [courseId] on this device.
  Future<Either<Failure, void>> unbookmarkCourse(String courseId);

  /// Fetch courses by their unique IDs.
  Future<Either<Failure, List<Course>>> getCoursesByIds(List<String> ids);
}
