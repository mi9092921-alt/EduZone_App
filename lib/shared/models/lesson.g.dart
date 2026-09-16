// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lesson.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Lesson _$LessonFromJson(Map<String, dynamic> json) => _Lesson(
  id: json['id'] as String,
  sectionId: json['section_id'] as String,
  courseId: json['course_id'] as String?,
  tenantId: json['tenant_id'] as String?,
  title: json['title'] as String,
  orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
  isPublished: json['is_published'] as bool? ?? true,
  isPreview: json['is_preview'] as bool? ?? false,
  durationSec: (json['duration_sec'] as num?)?.toInt(),
  hasAccess: json['has_access'] as bool? ?? false,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
  userProgress: (json['user_progress'] as List<dynamic>?)
      ?.map((e) => LessonProgress.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$LessonToJson(_Lesson instance) => <String, dynamic>{
  'id': instance.id,
  'section_id': instance.sectionId,
  'course_id': instance.courseId,
  'tenant_id': instance.tenantId,
  'title': instance.title,
  'order_index': instance.orderIndex,
  'is_published': instance.isPublished,
  'is_preview': instance.isPreview,
  'duration_sec': instance.durationSec,
  'has_access': instance.hasAccess,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
  'user_progress': instance.userProgress,
};
