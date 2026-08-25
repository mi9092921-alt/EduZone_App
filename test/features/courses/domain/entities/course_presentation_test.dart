import 'package:app/core/l10n/arb/app_localizations_en.dart';
import 'package:app/features/courses/domain/entities/course.dart';
import 'package:app/features/courses/domain/entities/lesson.dart';
import 'package:app/features/courses/domain/entities/section.dart';
import 'package:flutter_test/flutter_test.dart';

const _course = Course(
  id: 'c1',
  tenantId: 't1',
  title: 'Flutter Mastery',
  status: 'published',
);

void main() {
  final l10n = AppLocalizationsEn();

  group('CoursePresentation.ratingLabel', () {
    test('shows an em dash when there is no rating yet', () {
      expect(_course.ratingLabel, '—');
    });

    test('formats a rating to one decimal place', () {
      expect(_course.copyWith(rating: 4.567).ratingLabel, '4.6');
      expect(_course.copyWith(rating: 5).ratingLabel, '5.0');
    });
  });

  group('CoursePresentation.studentsLabel', () {
    test('is empty when the student count is unknown', () {
      expect(_course.studentsLabel, '');
    });

    test('shows the exact number under 1000', () {
      expect(_course.copyWith(studentsCount: 999).studentsLabel, '999');
      expect(_course.copyWith(studentsCount: 0).studentsLabel, '0');
    });

    test('abbreviates to one-decimal "k" at 1000 and above', () {
      expect(_course.copyWith(studentsCount: 1000).studentsLabel, '1.0k');
      expect(_course.copyWith(studentsCount: 12500).studentsLabel, '12.5k');
      expect(_course.copyWith(studentsCount: 999999).studentsLabel, '1000.0k');
    });
  });

  group('CoursePresentation.levelLocalized', () {
    test('maps the three known levels case-insensitively', () {
      expect(_course.copyWith(level: 'beginner').levelLocalized(l10n), l10n.levelBeginner);
      expect(_course.copyWith(level: 'BEGINNER').levelLocalized(l10n), l10n.levelBeginner);
      expect(
        _course.copyWith(level: 'intermediate').levelLocalized(l10n),
        l10n.levelIntermediate,
      );
      expect(_course.copyWith(level: 'advanced').levelLocalized(l10n), l10n.levelAdvanced);
    });

    test('falls back to the raw uppercased value for an unknown level', () {
      expect(_course.copyWith(level: 'expert').levelLocalized(l10n), 'EXPERT');
    });
  });

  group('CoursePresentation.computedTotalLessons', () {
    test('is 0 when the course has no joined sections', () {
      expect(_course.computedTotalLessons, 0);
    });

    test('sums lesson counts across every section', () {
      final course = _course.copyWith(
        sections: const [
          Section(
            id: 's1',
            courseId: 'c1',
            tenantId: 't1',
            title: 'Section 1',
            lessons: [
              Lesson(id: 'l1', sectionId: 's1', title: 'L1'),
              Lesson(id: 'l2', sectionId: 's1', title: 'L2'),
            ],
          ),
          Section(
            id: 's2',
            courseId: 'c1',
            tenantId: 't1',
            title: 'Section 2',
            lessons: [Lesson(id: 'l3', sectionId: 's2', title: 'L3')],
          ),
          Section(
            id: 's3',
            courseId: 'c1',
            tenantId: 't1',
            title: 'Section 3 (empty)',
          ),
        ],
      );

      expect(course.computedTotalLessons, 3);
    });
  });

  group('CoursePresentation.totalDurationMinutes', () {
    test('is 0 when there are no sections/lessons with a duration', () {
      expect(_course.totalDurationMinutes, 0);
    });

    test('sums lesson durations (seconds) across sections and rounds to minutes', () {
      final course = _course.copyWith(
        sections: const [
          Section(
            id: 's1',
            courseId: 'c1',
            tenantId: 't1',
            title: 'Section 1',
            lessons: [
              Lesson(id: 'l1', sectionId: 's1', title: 'L1', durationSec: 90),
              Lesson(id: 'l2', sectionId: 's1', title: 'L2', durationSec: 30),
            ],
          ),
        ],
      );

      // 120 seconds total -> exactly 2 minutes.
      expect(course.totalDurationMinutes, 2);
    });

    test('a lesson with no duration contributes 0, not a crash', () {
      final course = _course.copyWith(
        sections: const [
          Section(
            id: 's1',
            courseId: 'c1',
            tenantId: 't1',
            title: 'Section 1',
            lessons: [Lesson(id: 'l1', sectionId: 's1', title: 'L1')],
          ),
        ],
      );

      expect(course.totalDurationMinutes, 0);
    });
  });

  group('CoursePresentation.isNew', () {
    test('is false when createdAt is unknown', () {
      expect(_course.isNew, false);
    });

    test('is true within the last 14 days', () {
      final course = _course.copyWith(
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      );
      expect(course.isNew, true);
    });

    test('is false once older than 14 days', () {
      final course = _course.copyWith(
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
      );
      expect(course.isNew, false);
    });
  });
}
