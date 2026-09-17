import '../../../../shared/models/course.dart';
import '../../../../shared/models/course_rating.dart';
import '../../../../shared/models/lesson_content.dart';
import '../../domain/entities/course_enrollment.dart';
import '../../domain/entities/course_progress_summary.dart';

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

  /// Submits (or updates) the current student's 1-5 star rating for a
  /// course via the `rate_course` RPC and returns the refreshed
  /// course-wide aggregate.
  Future<CourseRatingAggregate> rateCourse({
    required String courseId,
    required int rating,
  });

  /// Reads the current student's own rating for a course (own-row only by
  /// the course_ratings SELECT policy), or null when not rated yet.
  Future<int?> getMyRating(String courseId);

  /// Resolves instructor display name/avatar for a batch of courses via
  /// the `get_courses_instructors` RPC (the users SELECT RLS hides other
  /// users' rows from students, so PostgREST teacher embeds return NULL).
  Future<Map<String, CourseInstructorInfo>> fetchInstructors(
    List<String> courseIds,
  );
}

/// Instructor display fields resolved by `get_courses_instructors`.
class CourseInstructorInfo {
  final String? name;
  final String? avatarUrl;

  const CourseInstructorInfo({this.name, this.avatarUrl});

  factory CourseInstructorInfo.fromJson(Map<String, dynamic> json) =>
      CourseInstructorInfo(
        name: json['instructor_name'] as String?,
        avatarUrl: json['instructor_avatar'] as String?,
      );
}

