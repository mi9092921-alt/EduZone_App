// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_enrollment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CourseEnrollment _$CourseEnrollmentFromJson(Map<String, dynamic> json) =>
    _CourseEnrollment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      courseId: json['course_id'] as String,
      tenantId: json['tenant_id'] as String,
      status: json['status'] as String? ?? 'active',
      enrolledAt: json['enrolled_at'] == null
          ? null
          : DateTime.parse(json['enrolled_at'] as String),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      progressPct: (json['progress_pct'] as num?)?.toDouble() ?? 0,
      completedLessons: (json['completed_lessons'] as num?)?.toInt() ?? 0,
      totalLessons: (json['total_lessons'] as num?)?.toInt() ?? 0,
      lastWatchedAt: json['last_watched_at'] == null
          ? null
          : DateTime.parse(json['last_watched_at'] as String),
      enrolledBy: json['enrolled_by'] as String?,
      revokedAt: json['revoked_at'] == null
          ? null
          : DateTime.parse(json['revoked_at'] as String),
      revokedBy: json['revoked_by'] as String?,
      revokeReason: json['revoke_reason'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      course: json['course'] == null
          ? null
          : Course.fromJson(json['course'] as Map<String, dynamic>),
      progressAvg: (json['progress_avg'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$CourseEnrollmentToJson(_CourseEnrollment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'course_id': instance.courseId,
      'tenant_id': instance.tenantId,
      'status': instance.status,
      'enrolled_at': instance.enrolledAt?.toIso8601String(),
      'expires_at': instance.expiresAt?.toIso8601String(),
      'completed_at': instance.completedAt?.toIso8601String(),
      'progress_pct': instance.progressPct,
      'completed_lessons': instance.completedLessons,
      'total_lessons': instance.totalLessons,
      'last_watched_at': instance.lastWatchedAt?.toIso8601String(),
      'enrolled_by': instance.enrolledBy,
      'revoked_at': instance.revokedAt?.toIso8601String(),
      'revoked_by': instance.revokedBy,
      'revoke_reason': instance.revokeReason,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'course': instance.course,
      'progress_avg': instance.progressAvg,
    };
