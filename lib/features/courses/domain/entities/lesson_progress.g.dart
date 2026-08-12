// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lesson_progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LessonProgress _$LessonProgressFromJson(Map<String, dynamic> json) =>
    _LessonProgress(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      courseId: json['course_id'] as String,
      lessonId: json['lesson_id'] as String?,
      tenantId: json['tenant_id'] as String,
      completed: json['completed'] as bool? ?? false,
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      progressPct: (json['progress_pct'] as num?)?.toDouble() ?? 0.0,
      watchTimeSec: (json['watch_time_sec'] as num?)?.toInt() ?? 0,
      lastWatched: json['last_watched'] == null
          ? null
          : DateTime.parse(json['last_watched'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$LessonProgressToJson(_LessonProgress instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'course_id': instance.courseId,
      'lesson_id': instance.lessonId,
      'tenant_id': instance.tenantId,
      'completed': instance.completed,
      'completed_at': instance.completedAt?.toIso8601String(),
      'progress_pct': instance.progressPct,
      'watch_time_sec': instance.watchTimeSec,
      'last_watched': instance.lastWatched?.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
