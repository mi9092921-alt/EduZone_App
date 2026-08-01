// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Course _$CourseFromJson(Map<String, dynamic> json) => _Course(
  id: json['id'] as String,
  tenantId: json['tenant_id'] as String,
  title: json['title'] as String,
  description: json['description'] as String?,
  status: json['status'] as String,
  thumbnailUrl: json['thumbnail_url'] as String?,
  slug: json['slug'] as String?,
  teacherId: json['teacher_id'] as String?,
  category: json['category'] as String?,
  level: json['level'] as String? ?? 'beginner',
  price: (json['price'] as num?)?.toDouble() ?? 0,
  isFree: json['is_free'] as bool? ?? true,
  isFeatured: json['is_featured'] as bool? ?? false,
  isDiscoverable: json['is_discoverable'] as bool? ?? true,
  regionId: json['region_id'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
  totalLessons: (json['total_lessons'] as num?)?.toInt(),
  rating: (json['rating'] as num?)?.toDouble(),
  studentsCount: (json['students_count'] as num?)?.toInt(),
  instructorName: json['instructor_name'] as String?,
  instructorAvatar: json['instructor_avatar'] as String?,
  prerequisites: (json['prerequisites'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  learningObjectives: (json['learning_objectives'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  language: json['language'] as String?,
  sections: (json['sections'] as List<dynamic>?)
      ?.map((e) => Section.fromJson(e as Map<String, dynamic>))
      .toList(),
  progressPct: (json['progress_pct'] as num?)?.toDouble(),
  completedLessons: (json['completed_lessons'] as num?)?.toInt(),
);

Map<String, dynamic> _$CourseToJson(_Course instance) => <String, dynamic>{
  'id': instance.id,
  'tenant_id': instance.tenantId,
  'title': instance.title,
  'description': instance.description,
  'status': instance.status,
  'thumbnail_url': instance.thumbnailUrl,
  'slug': instance.slug,
  'teacher_id': instance.teacherId,
  'category': instance.category,
  'level': instance.level,
  'price': instance.price,
  'is_free': instance.isFree,
  'is_featured': instance.isFeatured,
  'is_discoverable': instance.isDiscoverable,
  'region_id': instance.regionId,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
  'total_lessons': instance.totalLessons,
  'rating': instance.rating,
  'students_count': instance.studentsCount,
  'instructor_name': instance.instructorName,
  'instructor_avatar': instance.instructorAvatar,
  'prerequisites': instance.prerequisites,
  'learning_objectives': instance.learningObjectives,
  'language': instance.language,
  'sections': instance.sections,
  'progress_pct': instance.progressPct,
  'completed_lessons': instance.completedLessons,
};
