import 'package:freezed_annotation/freezed_annotation.dart';
import 'course.dart';

part 'course_enrollment.freezed.dart';
part 'course_enrollment.g.dart';

@freezed
abstract class CourseEnrollment with _$CourseEnrollment {
  const factory CourseEnrollment({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'course_id') required String courseId,
    @JsonKey(name: 'tenant_id') required String tenantId,
    @Default('active') String status,
    @JsonKey(name: 'enrolled_at') DateTime? enrolledAt,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
    @JsonKey(name: 'completed_at') DateTime? completedAt,
    
    // Progress Tracking
    @JsonKey(name: 'progress_pct') @Default(0) double progressPct,
    @JsonKey(name: 'completed_lessons') @Default(0) int completedLessons,
    @JsonKey(name: 'total_lessons') @Default(0) int totalLessons,
    @JsonKey(name: 'last_watched_at') DateTime? lastWatchedAt,
    @JsonKey(name: 'enrolled_by') String? enrolledBy,
    @JsonKey(name: 'revoked_at') DateTime? revokedAt,
    @JsonKey(name: 'revoked_by') String? revokedBy,
    @JsonKey(name: 'revoke_reason') String? revokeReason,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,

    // Virtual fields joined by PostgREST
    Course? course,
    @JsonKey(name: 'progress_avg') double? progressAvg,
  }) = _CourseEnrollment;

  factory CourseEnrollment.fromJson(Map<String, dynamic> json) => _$CourseEnrollmentFromJson(json);
}
