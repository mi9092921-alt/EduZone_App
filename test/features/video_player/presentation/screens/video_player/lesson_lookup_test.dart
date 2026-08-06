import 'package:app/features/courses/domain/entities/course.dart';
import 'package:app/features/courses/domain/entities/lesson.dart';
import 'package:app/features/courses/domain/entities/section.dart';
import 'package:app/features/video_player/presentation/screens/video_player/lesson_lookup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const lessonA1 = Lesson(id: 'a1', sectionId: 's1', title: 'A1');
  const lessonA2 = Lesson(id: 'a2', sectionId: 's1', title: 'A2');
  const lessonB1 = Lesson(id: 'b1', sectionId: 's2', title: 'B1');

  const sectionOne = Section(
    id: 's1',
    courseId: 'c1',
    tenantId: 't1',
    title: 'Section 1',
    lessons: [lessonA1, lessonA2],
  );

  const sectionTwo = Section(
    id: 's2',
    courseId: 'c1',
    tenantId: 't1',
    title: 'Section 2',
    lessons: [lessonB1],
  );

  const course = Course(
    id: 'c1',
    tenantId: 't1',
    title: 'Course 1',
    status: 'published',
    sections: [sectionOne, sectionTwo],
  );

  group('findLessonById', () {
    test('finds a lesson in the first section', () {
      expect(findLessonById(course, 'a1'), lessonA1);
    });

    test('finds a lesson in a later section', () {
      expect(findLessonById(course, 'b1'), lessonB1);
    });

    test('returns null when no lesson matches', () {
      expect(findLessonById(course, 'does-not-exist'), isNull);
    });

    test('returns null when the course has no sections', () {
      const emptyCourse = Course(
        id: 'c2',
        tenantId: 't1',
        title: 'Empty Course',
        status: 'published',
      );

      expect(findLessonById(emptyCourse, 'a1'), isNull);
    });

    test('returns null when a section has no lessons', () {
      const courseWithEmptySection = Course(
        id: 'c3',
        tenantId: 't1',
        title: 'Course 3',
        status: 'published',
        sections: [
          Section(
            id: 's3',
            courseId: 'c3',
            tenantId: 't1',
            title: 'Empty Section',
          ),
        ],
      );

      expect(findLessonById(courseWithEmptySection, 'a1'), isNull);
    });
  });
}
