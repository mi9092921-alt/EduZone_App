import 'package:app/features/courses/domain/entities/course.dart';
import 'package:app/features/courses/domain/entities/lesson.dart';
import 'package:app/features/courses/domain/entities/section.dart';

/// Finds the [Lesson] with [lessonId] anywhere in [course]'s sections.
///
/// Extracted from `video_player_screen.dart`'s private
/// `_VideoPlayerScreenState._findLesson` method — pure data traversal with
/// no widget/BuildContext dependency, so it can be unit-tested directly
/// against plain [Course]/[Section]/[Lesson] entities.
///
/// Returns `null` if no section contains a lesson with that id.
Lesson? findLessonById(Course course, String lessonId) {
  final sections = course.sections ?? const <Section>[];

  for (final section in sections) {
    final lessons = section.lessons ?? const <Lesson>[];

    for (final lesson in lessons) {
      if (lesson.id == lessonId) return lesson;
    }
  }
  return null;
}
