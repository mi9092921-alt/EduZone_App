import 'package:freezed_annotation/freezed_annotation.dart';

part 'resume_lesson.freezed.dart';
part 'resume_lesson.g.dart';

@freezed
abstract class ResumeLesson with _$ResumeLesson {
  const factory ResumeLesson({
    @JsonKey(name: 'progress_pct') required double progressPct,
    @JsonKey(name: 'last_watched') required DateTime lastWatched,
    @JsonKey(name: 'lesson_id') required String lessonId,
    @JsonKey(name: 'lesson_title') required String lessonTitle,
    @JsonKey(name: 'duration_sec') int? durationSec,
    @JsonKey(name: 'section_title') required String sectionTitle,
    @JsonKey(name: 'course_id') required String courseId,
    @JsonKey(name: 'course_title') required String courseTitle,
    @JsonKey(name: 'thumbnail_url') String? thumbnailUrl,
  }) = _ResumeLesson;

  factory ResumeLesson.fromJson(Map<String, dynamic> json) =>
      _$ResumeLessonFromJson(json);

  /// Factory for skeleton dummy data
  factory ResumeLesson.skeleton() => ResumeLesson(
        progressPct: 50,
        lastWatched: DateTime.now(),
        lessonId: 'skeleton',
        lessonTitle: 'Loading Lesson Title...',
        sectionTitle: 'Loading Section Title...',
        courseId: 'skeleton',
        courseTitle: 'Loading Course Title...',
      );
}
