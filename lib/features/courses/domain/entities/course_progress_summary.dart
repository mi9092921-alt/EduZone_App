import 'package:freezed_annotation/freezed_annotation.dart';

part 'course_progress_summary.freezed.dart';
part 'course_progress_summary.g.dart';

/// Aggregated progress data for a single course.
///
/// Returned by the `get_course_progress_summary` RPC.
/// [progressPct] is an integer (0–100) to avoid UI jitter;
/// smooth animation is handled on the widget side.
@freezed
abstract class CourseProgressSummary with _$CourseProgressSummary {
  const CourseProgressSummary._();

  const factory CourseProgressSummary({
    @JsonKey(name: 'courseId') String? courseId,
    @JsonKey(name: 'enrolledCount') @Default(0) int enrolledCount,
    @JsonKey(name: 'avgProgress') @Default(0.0) double avgProgress,
    @JsonKey(name: 'completedCount') @Default(0) int completedCount,
  }) = _CourseProgressSummary;

  factory CourseProgressSummary.fromJson(Map<String, dynamic> json) =>
      _$CourseProgressSummaryFromJson(json);

  /// Normalized average progress as a 0.0–1.0 double.
  double get normalizedProgress => avgProgress.clamp(0, 100) / 100.0;
}

/// Three distinct UI states for progress display.
enum ProgressState { notStarted, inProgress, completed }
