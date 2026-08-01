// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'section.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Section _$SectionFromJson(Map<String, dynamic> json) => _Section(
  id: json['id'] as String,
  courseId: json['course_id'] as String,
  tenantId: json['tenant_id'] as String,
  title: json['title'] as String,
  description: json['description'] as String?,
  orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
  isPublished: json['is_published'] as bool? ?? false,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
  lessons: (json['lessons'] as List<dynamic>?)
      ?.map((e) => Lesson.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SectionToJson(_Section instance) => <String, dynamic>{
  'id': instance.id,
  'course_id': instance.courseId,
  'tenant_id': instance.tenantId,
  'title': instance.title,
  'description': instance.description,
  'order_index': instance.orderIndex,
  'is_published': instance.isPublished,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
  'lessons': instance.lessons,
};
