import 'package:freezed_annotation/freezed_annotation.dart';

part 'lesson_progress.freezed.dart';
part 'lesson_progress.g.dart';

@freezed
abstract class LessonProgress with _$LessonProgress {
  const factory LessonProgress({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'course_id') required String courseId,
    @JsonKey(name: 'lesson_id') String? lessonId,
    @JsonKey(name: 'tenant_id') required String tenantId,
    @Default(false) bool completed,
    @JsonKey(name: 'completed_at') DateTime? completedAt,
    @JsonKey(name: 'progress_pct') @Default(0.0) double progressPct,
    @JsonKey(name: 'watch_time_sec') @Default(0) int watchTimeSec,
    @JsonKey(name: 'last_watched') DateTime? lastWatched,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _LessonProgress;

  factory LessonProgress.fromJson(Map<String, dynamic> json) => _$LessonProgressFromJson(json);
}
