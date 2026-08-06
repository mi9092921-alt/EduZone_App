import 'package:app/features/courses/data/datasources/courses_queries.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CoursesQueries', () {
    test('teacherJoin selects the instructor fields the mapper depends on', () {
      expect(CoursesQueries.teacherJoin, contains('first_name'));
      expect(CoursesQueries.teacherJoin, contains('last_name'));
      expect(CoursesQueries.teacherJoin, contains('avatar_url'));
    });

    test('lightSectionsWithLessons selects the columns Course.fromJson needs', () {
      expect(CoursesQueries.lightSectionsWithLessons, contains('sections('));
      expect(CoursesQueries.lightSectionsWithLessons, contains('lessons('));
      expect(CoursesQueries.lightSectionsWithLessons, contains('is_preview'));
      expect(CoursesQueries.lightSectionsWithLessons, contains('duration_sec'));
    });
  });
}
