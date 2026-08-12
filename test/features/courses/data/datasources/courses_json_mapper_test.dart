// ignore_for_file: avoid_dynamic_calls

import 'package:app/features/courses/data/datasources/courses_json_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CoursesJsonMapper.applyInstructorFields', () {
    test('flattens first_name + last_name into instructor_name', () {
      final target = <String, dynamic>{};

      CoursesJsonMapper.applyInstructorFields(
        target: target,
        teacherJson: {
          'first_name': 'Ada',
          'last_name': 'Lovelace',
          'avatar_url': 'https://example.com/ada.png',
        },
      );

      expect(target['instructor_name'], 'Ada Lovelace');
      expect(target['instructor_avatar'], 'https://example.com/ada.png');
    });

    test('trims a lone first_name with no last_name', () {
      final target = <String, dynamic>{};

      CoursesJsonMapper.applyInstructorFields(
        target: target,
        teacherJson: {'first_name': 'Ada'},
      );

      expect(target['instructor_name'], 'Ada');
    });

    test('is a no-op when teacherJson is null', () {
      final target = <String, dynamic>{'instructor_name': 'unchanged'};

      CoursesJsonMapper.applyInstructorFields(
        target: target,
        teacherJson: null,
      );

      expect(target['instructor_name'], 'unchanged');
      expect(target.containsKey('instructor_avatar'), isFalse);
    });

    test('handles a completely empty teacher map', () {
      final target = <String, dynamic>{};

      CoursesJsonMapper.applyInstructorFields(target: target, teacherJson: {});

      expect(target['instructor_name'], '');
      expect(target['instructor_avatar'], isNull);
    });
  });

  group('CoursesJsonMapper.backfillTotalLessons', () {
    test('leaves total_lessons untouched when it is already non-zero', () {
      final rawJson = {'total_lessons': 7, 'sections': []};
      final target = Map<String, dynamic>.from(rawJson);

      CoursesJsonMapper.backfillTotalLessons(rawJson: rawJson, target: target);

      expect(target['total_lessons'], 7);
    });

    test('recomputes from sections->lessons when total_lessons is 0', () {
      final rawJson = {
        'total_lessons': 0,
        'sections': [
          {
            'lessons': [
              {'id': 'l1'},
              {'id': 'l2'},
            ],
          },
          {
            'lessons': [
              {'id': 'l3'},
            ],
          },
        ],
      };
      final target = Map<String, dynamic>.from(rawJson);

      CoursesJsonMapper.backfillTotalLessons(rawJson: rawJson, target: target);

      expect(target['total_lessons'], 3);
    });

    test('treats a missing total_lessons key the same as 0', () {
      final rawJson = {
        'sections': [
          {
            'lessons': [
              {'id': 'l1'},
            ],
          },
        ],
      };
      final target = Map<String, dynamic>.from(rawJson);

      CoursesJsonMapper.backfillTotalLessons(rawJson: rawJson, target: target);

      expect(target['total_lessons'], 1);
    });

    test('computes 0 when there are no sections at all', () {
      final rawJson = <String, dynamic>{'total_lessons': 0};
      final target = Map<String, dynamic>.from(rawJson);

      CoursesJsonMapper.backfillTotalLessons(rawJson: rawJson, target: target);

      expect(target['total_lessons'], 0);
    });

    test('debugLog: false does not throw and does not change the result', () {
      final rawJson = {
        'id': 'c1',
        'title': 'Course 1',
        'total_lessons': 0,
        'sections': [
          {
            'lessons': [
              {'id': 'l1'},
            ],
          },
        ],
      };
      final target = Map<String, dynamic>.from(rawJson);

      CoursesJsonMapper.backfillTotalLessons(
        rawJson: rawJson,
        target: target,
      );

      expect(target['total_lessons'], 1);
    });
  });

  group('CoursesJsonMapper.flattenLearningObjectives', () {
    test('flattens objects to plain strings, sorted by order_index', () {
      final target = <String, dynamic>{
        'learning_objectives': [
          {'objective': 'Second', 'order_index': 1},
          {'objective': 'First', 'order_index': 0},
        ],
      };

      CoursesJsonMapper.flattenLearningObjectives(target);

      expect(target['learning_objectives'], ['First', 'Second']);
    });

    test('drops empty objective strings', () {
      final target = <String, dynamic>{
        'learning_objectives': [
          {'objective': '', 'order_index': 0},
          {'objective': 'Keep me', 'order_index': 1},
        ],
      };

      CoursesJsonMapper.flattenLearningObjectives(target);

      expect(target['learning_objectives'], ['Keep me']);
    });

    test('treats a missing order_index as 0 for sorting', () {
      final target = <String, dynamic>{
        'learning_objectives': [
          {'objective': 'B', 'order_index': 5},
          {'objective': 'A'},
        ],
      };

      CoursesJsonMapper.flattenLearningObjectives(target);

      expect(target['learning_objectives'], ['A', 'B']);
    });

    test('is a no-op when learning_objectives is not a List', () {
      final target = <String, dynamic>{'learning_objectives': null};

      CoursesJsonMapper.flattenLearningObjectives(target);

      expect(target['learning_objectives'], isNull);
    });

    test('handles an empty list', () {
      final target = <String, dynamic>{'learning_objectives': <dynamic>[]};

      CoursesJsonMapper.flattenLearningObjectives(target);

      expect(target['learning_objectives'], isEmpty);
    });
  });

  group('CoursesJsonMapper.flattenPrerequisites', () {
    test('prefers the joined prerequisite course title', () {
      final target = <String, dynamic>{
        'prerequisites': [
          {
            'prerequisite_course_id': 'course-1',
            'prerequisite_course': {'title': 'Intro to Dart'},
          },
        ],
      };

      CoursesJsonMapper.flattenPrerequisites(target);

      expect(target['prerequisites'], ['Intro to Dart']);
    });

    test('falls back to the raw id when the joined title is missing', () {
      final target = <String, dynamic>{
        'prerequisites': [
          {'prerequisite_course_id': 'course-1', 'prerequisite_course': null},
        ],
      };

      CoursesJsonMapper.flattenPrerequisites(target);

      expect(target['prerequisites'], ['course-1']);
    });

    test('drops entries with neither a title nor an id', () {
      final target = <String, dynamic>{
        'prerequisites': [
          {'prerequisite_course_id': null, 'prerequisite_course': null},
          {
            'prerequisite_course_id': 'course-2',
            'prerequisite_course': {'title': 'Kept'},
          },
        ],
      };

      CoursesJsonMapper.flattenPrerequisites(target);

      expect(target['prerequisites'], ['Kept']);
    });

    test('is a no-op when prerequisites is not a List', () {
      final target = <String, dynamic>{'prerequisites': 'not-a-list'};

      CoursesJsonMapper.flattenPrerequisites(target);

      expect(target['prerequisites'], 'not-a-list');
    });
  });

  group('CoursesJsonMapper.filterUserProgressForCurrentUser', () {
    test('keeps only progress rows matching userId', () {
      final target = <String, dynamic>{
        'sections': [
          {
            'lessons': [
              {
                'user_progress': [
                  {'user_id': 'u1', 'completed': true},
                  {'user_id': 'u2', 'completed': false},
                ],
              },
            ],
          },
        ],
      };

      CoursesJsonMapper.filterUserProgressForCurrentUser(target, 'u1');

      
      final lessons = (target['sections'] as List).first['lessons'] as List;
      final progress = lessons.first['user_progress'] as List;
      expect(progress, hasLength(1));
      expect(progress.first['user_id'], 'u1');
    });

    test('clears every user_progress list when userId is null', () {
      final target = <String, dynamic>{
        'sections': [
          {
            'lessons': [
              {
                'user_progress': [
                  {'user_id': 'u1'},
                ],
              },
            ],
          },
        ],
      };

      CoursesJsonMapper.filterUserProgressForCurrentUser(target, null);

      final lessons = (target['sections'] as List).first['lessons'] as List;
      expect(lessons.first['user_progress'], isEmpty);
    });

    test('is a no-op when sections is missing', () {
      final target = <String, dynamic>{};

      expect(
        () => CoursesJsonMapper.filterUserProgressForCurrentUser(target, 'u1'),
        returnsNormally,
      );
    });

    test('skips lessons that have no user_progress field, without throwing', () {
      final target = <String, dynamic>{
        'sections': [
          {
            'lessons': [
              {'id': 'l1'},
            ],
          },
        ],
      };

      expect(
        () => CoursesJsonMapper.filterUserProgressForCurrentUser(target, 'u1'),
        returnsNormally,
      );
    });

    test('handles multiple sections and multiple lessons per section', () {
      final target = <String, dynamic>{
        'sections': [
          {
            'lessons': [
              {
                'user_progress': [
                  {'user_id': 'u1'},
                  {'user_id': 'u2'},
                ],
              },
              {
                'user_progress': [
                  {'user_id': 'u1'},
                ],
              },
            ],
          },
          {
            'lessons': [
              {
                'user_progress': [
                  {'user_id': 'u2'},
                ],
              },
            ],
          },
        ],
      };

      CoursesJsonMapper.filterUserProgressForCurrentUser(target, 'u1');

      final sections = target['sections'] as List;
      final firstSectionLessons = sections[0]['lessons'] as List;
      final secondSectionLessons = sections[1]['lessons'] as List;

      expect(firstSectionLessons[0]['user_progress'], hasLength(1));
      expect(firstSectionLessons[1]['user_progress'], hasLength(1));
      expect(secondSectionLessons[0]['user_progress'], isEmpty);
    });
  });
}
