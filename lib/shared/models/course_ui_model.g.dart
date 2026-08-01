// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_ui_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CourseUIModel _$CourseUIModelFromJson(Map<String, dynamic> json) =>
    _CourseUIModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String,
      instructorName: json['instructorName'] as String,
      category: json['category'] as String?,
      level: json['level'] as String?,
      duration: json['duration'] as String?,
      totalLessons: (json['totalLessons'] as num?)?.toInt(),
      rating: (json['rating'] as num?)?.toDouble(),
      studentsCount: (json['studentsCount'] as num?)?.toInt(),
      price: json['price'] as String?,
      isFeatured: json['isFeatured'] as bool? ?? false,
      isFree: json['isFree'] as bool? ?? false,
      status: json['status'] as String?,
      progress: (json['progress'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$CourseUIModelToJson(_CourseUIModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'thumbnailUrl': instance.thumbnailUrl,
      'instructorName': instance.instructorName,
      'category': instance.category,
      'level': instance.level,
      'duration': instance.duration,
      'totalLessons': instance.totalLessons,
      'rating': instance.rating,
      'studentsCount': instance.studentsCount,
      'price': instance.price,
      'isFeatured': instance.isFeatured,
      'isFree': instance.isFree,
      'status': instance.status,
      'progress': instance.progress,
    };
