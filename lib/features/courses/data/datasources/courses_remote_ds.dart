import '../../domain/entities/course.dart';
import '../../domain/entities/course_enrollment.dart';
import '../../domain/entities/course_progress_summary.dart';
import '../../domain/entities/lesson_content.dart';

abstract class CoursesRemoteDataSource {
  Future<List<CourseEnrollment>> getMyCourses();
  Future<Course> getCourseDetails(String courseId);

  /// Calls the `get_course_outline` RPC — returns sections + lesson
  /// metadata without any video URLs.
  Future<Course> getCourseOutline(String courseId);

  Future<CourseEnrollment?> getMyCourseEnrollment(String courseId);
  Future<void> updateLessonProgress({
    required String courseId,
    required String lessonId,
    required bool completed,
    required double progressPct,
    int? watchTimeSec,
  });
  Future<List<Course>> getPublicCourses({required int page, required int limit});
  Future<Set<String>> getUserSubscribedCourseIds();
  Future<void> enrollInCourse(String courseId);

  /// Calls the `get_lesson_content` RPC which validates enrollment,
  /// logs the access attempt, and returns the video path.
  Future<LessonContent> getLessonContent(String lessonId);

  /// Calls the `get_course_progress_summary` RPC to get aggregated
  /// progress stats (completed/total lessons, percentage, last watched).
  Future<CourseProgressSummary> getCourseProgressSummary(String courseId);

  /// Fetch courses by their unique IDs.
  Future<List<Course>> getCoursesByIds(List<String> ids);
}

