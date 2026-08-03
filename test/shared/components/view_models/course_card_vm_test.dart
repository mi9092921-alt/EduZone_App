// ignore_for_file: avoid_redundant_argument_values

import 'package:app/core/l10n/arb/app_localizations_en.dart';
import 'package:app/shared/components/view_models/course_card_vm.dart';
import 'package:app/shared/models/course_ui_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsEn();

  CourseUIModel baseModel({
    String id = '1',
    String title = 'Flutter Advanced',
    String thumbnailUrl = '',
    String instructorName = 'John Doe',
    String? category,
    String? level,
    int? totalLessons,
    double? rating,
    int? studentsCount,
    String? price,
    bool isFeatured = false,
    bool isFree = false,
    String? status,
    double? progress,
  }) {
    return CourseUIModel(
      id: id,
      title: title,
      thumbnailUrl: thumbnailUrl,
      instructorName: instructorName,
      category: category,
      level: level,
      totalLessons: totalLessons,
      rating: rating,
      studentsCount: studentsCount,
      price: price,
      isFeatured: isFeatured,
      isFree: isFree,
      status: status,
      progress: progress,
    );
  }

  group('displayPrice', () {
    test('returns free label when course is free', () {
      final vm = CourseCardVM(model: baseModel(isFree: true, price: '\$10'), l10n: l10n);
      expect(vm.displayPrice, l10n.freeLabel);
    });

    test('returns the price when present and not free', () {
      final vm = CourseCardVM(model: baseModel(isFree: false, price: '\$49.99'), l10n: l10n);
      expect(vm.displayPrice, '\$49.99');
    });

    test('falls back to paidPrice label when price is null and not free', () {
      final vm = CourseCardVM(model: baseModel(isFree: false, price: null), l10n: l10n);
      expect(vm.displayPrice, l10n.paidPrice);
    });
  });

  group('normalizedRating / ratingString', () {
    test('defaults to 0.0 when rating is null', () {
      final vm = CourseCardVM(model: baseModel(rating: null), l10n: l10n);
      expect(vm.normalizedRating, 0.0);
      expect(vm.ratingString, '0.0');
    });

    test('clamps ratings above 5.0 down to 5.0', () {
      final vm = CourseCardVM(model: baseModel(rating: 7.2), l10n: l10n);
      expect(vm.normalizedRating, 5.0);
      expect(vm.ratingString, '5.0');
    });

    test('clamps negative ratings up to 0.0', () {
      final vm = CourseCardVM(model: baseModel(rating: -3.0), l10n: l10n);
      expect(vm.normalizedRating, 0.0);
    });

    test('passes through valid in-range ratings unchanged', () {
      final vm = CourseCardVM(model: baseModel(rating: 4.8), l10n: l10n);
      expect(vm.normalizedRating, 4.8);
      expect(vm.ratingString, '4.8');
    });
  });

  group('studentsLabel', () {
    test('shows raw count under 1000', () {
      final vm = CourseCardVM(model: baseModel(studentsCount: 950), l10n: l10n);
      expect(vm.studentsLabel, '950');
    });

    test('defaults to "0" when null', () {
      final vm = CourseCardVM(model: baseModel(studentsCount: null), l10n: l10n);
      expect(vm.studentsLabel, '0');
    });

    test('formats counts of 1000+ as "Xk"', () {
      final vm = CourseCardVM(model: baseModel(studentsCount: 1500), l10n: l10n);
      expect(vm.studentsLabel, '1.5k');
    });

    test('formats exactly 1000 as "1.0k"', () {
      final vm = CourseCardVM(model: baseModel(studentsCount: 1000), l10n: l10n);
      expect(vm.studentsLabel, '1.0k');
    });
  });

  group('progressString / hasProgress', () {
    test('defaults to 0% and hasProgress false when progress is null', () {
      final vm = CourseCardVM(model: baseModel(progress: null), l10n: l10n);
      expect(vm.progressString, '0%');
      expect(vm.hasProgress, isFalse);
    });

    test('truncates fractional progress to an int percentage', () {
      final vm = CourseCardVM(model: baseModel(progress: 42.9), l10n: l10n);
      expect(vm.progressString, '42%');
      expect(vm.hasProgress, isTrue);
    });
  });

  group('hasLessons / lessonsLabel', () {
    test('hasLessons is false when totalLessons is null or zero', () {
      expect(CourseCardVM(model: baseModel(totalLessons: null), l10n: l10n).hasLessons, isFalse);
      expect(CourseCardVM(model: baseModel(totalLessons: 0), l10n: l10n).hasLessons, isFalse);
    });

    test('hasLessons is true when totalLessons is positive', () {
      final vm = CourseCardVM(model: baseModel(totalLessons: 12), l10n: l10n);
      expect(vm.hasLessons, isTrue);
      expect(vm.lessonsLabel, l10n.lessonsCount(12));
    });
  });

  group('category / level / featured / status flags', () {
    test('hasCategory is false for null or empty category', () {
      expect(CourseCardVM(model: baseModel(category: null), l10n: l10n).hasCategory, isFalse);
      expect(CourseCardVM(model: baseModel(category: ''), l10n: l10n).hasCategory, isFalse);
    });

    test('categoryLabel falls back to generalCategory when null', () {
      final vm = CourseCardVM(model: baseModel(category: null), l10n: l10n);
      expect(vm.categoryLabel, l10n.generalCategory);
    });

    test('categoryLabel returns the raw category when present', () {
      final vm = CourseCardVM(model: baseModel(category: 'Development'), l10n: l10n);
      expect(vm.categoryLabel, 'Development');
    });

    test('levelLabel maps known level keys case-insensitively', () {
      expect(CourseCardVM(model: baseModel(level: 'beginner'), l10n: l10n).levelLabel, l10n.levelBeginner);
      expect(CourseCardVM(model: baseModel(level: 'INTERMEDIATE'), l10n: l10n).levelLabel, l10n.levelIntermediate);
      expect(CourseCardVM(model: baseModel(level: 'Advanced'), l10n: l10n).levelLabel, l10n.levelAdvanced);
    });

    test('levelLabel falls back to the raw level string for unknown values', () {
      final vm = CourseCardVM(model: baseModel(level: 'expert'), l10n: l10n);
      expect(vm.levelLabel, 'expert');
    });

    test('levelLabel falls back to levelBeginner when level is null', () {
      final vm = CourseCardVM(model: baseModel(level: null), l10n: l10n);
      expect(vm.levelLabel, l10n.levelBeginner);
    });

    test('hasRating is false when rating is null or zero', () {
      expect(CourseCardVM(model: baseModel(rating: null), l10n: l10n).hasRating, isFalse);
      expect(CourseCardVM(model: baseModel(rating: 0.0), l10n: l10n).hasRating, isFalse);
    });

    test('hasStatus reflects a non-empty status string', () {
      expect(CourseCardVM(model: baseModel(status: null), l10n: l10n).hasStatus, isFalse);
      expect(CourseCardVM(model: baseModel(status: 'New'), l10n: l10n).hasStatus, isTrue);
    });

    test('isFeatured mirrors the model flag', () {
      expect(CourseCardVM(model: baseModel(isFeatured: true), l10n: l10n).isFeatured, isTrue);
      expect(CourseCardVM(model: baseModel(isFeatured: false), l10n: l10n).isFeatured, isFalse);
    });

    test('showInstructor is true whenever instructorName is non-empty', () {
      final vm = CourseCardVM(model: baseModel(instructorName: 'Jane'), l10n: l10n);
      expect(vm.showInstructor, isTrue);
    });
  });
}
