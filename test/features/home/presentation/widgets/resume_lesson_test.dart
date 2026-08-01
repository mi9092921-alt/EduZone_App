import 'package:app/features/home/domain/entities/resume_lesson.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResumeLesson.fromJson', () {
    test('parses a full snake_case JSON payload correctly', () {
      final json = {
        'progress_pct': 42.5,
        'last_watched': '2024-03-10T12:00:00.000Z',
        'lesson_id': 'lesson-1',
        'lesson_title': 'Intro to Widgets',
        'duration_sec': 600,
        'section_title': 'Getting Started',
        'course_id': 'course-1',
        'course_title': 'Flutter Basics',
        'thumbnail_url': 'https://example.com/thumb.jpg',
      };

      final lesson = ResumeLesson.fromJson(json);

      expect(lesson.progressPct, 42.5);
      expect(lesson.lastWatched, DateTime.parse('2024-03-10T12:00:00.000Z'));
      expect(lesson.lessonId, 'lesson-1');
      expect(lesson.lessonTitle, 'Intro to Widgets');
      expect(lesson.durationSec, 600);
      expect(lesson.sectionTitle, 'Getting Started');
      expect(lesson.courseId, 'course-1');
      expect(lesson.courseTitle, 'Flutter Basics');
      expect(lesson.thumbnailUrl, 'https://example.com/thumb.jpg');
    });

    test('parses correctly when optional fields are absent', () {
      final json = {
        'progress_pct': 0.0,
        'last_watched': '2024-01-01T00:00:00.000Z',
        'lesson_id': 'lesson-2',
        'lesson_title': 'No Duration Lesson',
        'section_title': 'Section',
        'course_id': 'course-2',
        'course_title': 'Course',
      };

      final lesson = ResumeLesson.fromJson(json);

      expect(lesson.durationSec, isNull);
      expect(lesson.thumbnailUrl, isNull);
    });

    test('accepts an integer progress_pct value (num -> double coercion)', () {
      final json = {
        'progress_pct': 50,
        'last_watched': '2024-01-01T00:00:00.000Z',
        'lesson_id': 'lesson-3',
        'lesson_title': 'Lesson',
        'section_title': 'Section',
        'course_id': 'course-3',
        'course_title': 'Course',
      };

      final lesson = ResumeLesson.fromJson(json);

      expect(lesson.progressPct, 50.0);
    });
  });

  group('ResumeLesson.toJson', () {
    test('serializes back to the expected snake_case keys', () {
      final lesson = ResumeLesson(
        progressPct: 75.0,
        lastWatched: DateTime.utc(2024, 5),
        lessonId: 'lesson-4',
        lessonTitle: 'Lesson Title',
        durationSec: 120,
        sectionTitle: 'Section Title',
        courseId: 'course-4',
        courseTitle: 'Course Title',
        thumbnailUrl: 'https://example.com/t.jpg',
      );

      final json = lesson.toJson();

      expect(json['progress_pct'], 75.0);
      expect(json['lesson_id'], 'lesson-4');
      expect(json['lesson_title'], 'Lesson Title');
      expect(json['duration_sec'], 120);
      expect(json['section_title'], 'Section Title');
      expect(json['course_id'], 'course-4');
      expect(json['course_title'], 'Course Title');
      expect(json['thumbnail_url'], 'https://example.com/t.jpg');
    });
  });

  group('equality (freezed value semantics)', () {
    test('two lessons with identical fields are equal', () {
      final lastWatched = DateTime(2024);
      final a = ResumeLesson(
        progressPct: 10,
        lastWatched: lastWatched,
        lessonId: 'l1',
        lessonTitle: 'Title',
        sectionTitle: 'Section',
        courseId: 'c1',
        courseTitle: 'Course',
      );
      final b = ResumeLesson(
        progressPct: 10,
        lastWatched: lastWatched,
        lessonId: 'l1',
        lessonTitle: 'Title',
        sectionTitle: 'Section',
        courseId: 'c1',
        courseTitle: 'Course',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('lessons differing by a single field are not equal', () {
      final lastWatched = DateTime(2024);
      final a = ResumeLesson(
        progressPct: 10,
        lastWatched: lastWatched,
        lessonId: 'l1',
        lessonTitle: 'Title',
        sectionTitle: 'Section',
        courseId: 'c1',
        courseTitle: 'Course',
      );
      final b = a.copyWith(progressPct: 99);

      expect(a, isNot(equals(b)));
    });
  });

  group('ResumeLesson.skeleton', () {
    test('produces placeholder data usable for loading/skeleton UI', () {
      final skeleton = ResumeLesson.skeleton();

      expect(skeleton.lessonId, 'skeleton');
      expect(skeleton.courseId, 'skeleton');
      expect(skeleton.progressPct, 50);
      expect(skeleton.lessonTitle, isNotEmpty);
      expect(skeleton.sectionTitle, isNotEmpty);
      expect(skeleton.courseTitle, isNotEmpty);
      // Thumbnail/duration are intentionally absent in the skeleton state.
      expect(skeleton.thumbnailUrl, isNull);
      expect(skeleton.durationSec, isNull);
    });
  });
}
