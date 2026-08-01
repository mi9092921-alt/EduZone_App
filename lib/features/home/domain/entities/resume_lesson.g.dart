// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resume_lesson.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ResumeLesson _$ResumeLessonFromJson(Map<String, dynamic> json) =>
    _ResumeLesson(
      progressPct: (json['progress_pct'] as num).toDouble(),
      lastWatched: DateTime.parse(json['last_watched'] as String),
      lessonId: json['lesson_id'] as String,
      lessonTitle: json['lesson_title'] as String,
      durationSec: (json['duration_sec'] as num?)?.toInt(),
      sectionTitle: json['section_title'] as String,
      courseId: json['course_id'] as String,
      courseTitle: json['course_title'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
    );

Map<String, dynamic> _$ResumeLessonToJson(_ResumeLesson instance) =>
    <String, dynamic>{
      'progress_pct': instance.progressPct,
      'last_watched': instance.lastWatched.toIso8601String(),
      'lesson_id': instance.lessonId,
      'lesson_title': instance.lessonTitle,
      'duration_sec': instance.durationSec,
      'section_title': instance.sectionTitle,
      'course_id': instance.courseId,
      'course_title': instance.courseTitle,
      'thumbnail_url': instance.thumbnailUrl,
    };
