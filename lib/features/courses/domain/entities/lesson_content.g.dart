// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lesson_content.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LessonContent _$LessonContentFromJson(Map<String, dynamic> json) =>
    _LessonContent(
      lessonId: json['lessonId'] as String,
      courseId: json['courseId'] as String,
      isPreview: json['isPreview'] as bool? ?? false,
      videoUrl: json['videoPath'] as String?,
      provider: json['provider'] as String? ?? 'youtube',
      duration: (json['durationSec'] as num?)?.toInt(),
      captionsUrl: json['captionsPath'] as String?,
      title: json['title'] as String?,
      hasAccess: json['has_access'] as bool? ?? false,
      previewUrl: json['preview_url'] as String?,
    );

Map<String, dynamic> _$LessonContentToJson(_LessonContent instance) =>
    <String, dynamic>{
      'lessonId': instance.lessonId,
      'courseId': instance.courseId,
      'isPreview': instance.isPreview,
      'videoPath': instance.videoUrl,
      'provider': instance.provider,
      'durationSec': instance.duration,
      'captionsPath': instance.captionsUrl,
      'title': instance.title,
      'has_access': instance.hasAccess,
      'preview_url': instance.previewUrl,
    };
