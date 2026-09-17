/// Course-wide rating aggregate returned by the `rate_course` RPC and
/// used across the courses feature's layers (same shared-model pattern as
/// [Course]/[TodoItem]: data, domain, and presentation all import it).
class CourseRatingAggregate {
  final String courseId;

  /// Course-wide average (1.0–5.0), null when no live ratings exist.
  final double? rating;

  /// Count of non-deleted ratings backing [rating].
  final int ratingCount;

  const CourseRatingAggregate({
    required this.courseId,
    required this.ratingCount,
    this.rating,
  });

  factory CourseRatingAggregate.fromJson(Map<String, dynamic> json) =>
      CourseRatingAggregate(
        courseId: json['course_id'] as String,
        rating: (json['rating'] as num?)?.toDouble(),
        ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      );
}
