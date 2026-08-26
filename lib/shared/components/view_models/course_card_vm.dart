import '../../../../core/l10n/arb/app_localizations.dart';
import '../../models/course_ui_model.dart';

/// ViewModel for the CourseCard to strictly decouple UI logic from presentation.
/// Handles all text formatting, fallback values, and normalization.
class CourseCardVM {
  final CourseUIModel model;
  final AppLocalizations l10n;

  const CourseCardVM({required this.model, required this.l10n});

  /// Formatted price for display.
  String get displayPrice {
    if (model.isFree) return l10n.freeLabel;
    return model.price ?? l10n.paidPrice;
  }

  /// Normalized rating ensured to be within 0-5 range.
  double get normalizedRating => (model.rating ?? 0.0).clamp(0.0, 5.0);

  /// Formatted rating string.
  String get ratingString => normalizedRating.toStringAsFixed(1);

  /// Label for the number of lessons.
  String get lessonsLabel {
    final count = model.totalLessons ?? 0;
    return l10n.lessonsCount(count);
  }

  /// Formatted student count (e.g., 1.2k).
  String get studentsLabel {
    final count = model.studentsCount ?? 0;
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  /// Formatted progress percentage.
  String get progressString => '${(model.progress ?? 0.0).toInt()}%';

  /// Whether the course has progress data.
  bool get hasProgress => model.progress != null;

  /// Whether the course has lessons data.
  bool get hasLessons => model.totalLessons != null && model.totalLessons! > 0;

  /// Whether the course has a category.
  bool get hasCategory => model.category != null && model.category!.isNotEmpty;

  /// Whether the course has a level defined.
  bool get hasLevel => model.level != null && model.level!.isNotEmpty;

  /// Whether the course has a valid rating to display.
  bool get hasRating => model.rating != null && model.rating! > 0;

  /// Whether the course is featured.
  bool get isFeatured => model.isFeatured;

  /// Whether the course has a status label.
  bool get hasStatus => model.status != null && model.status!.isNotEmpty;

  /// Localized status label.
  String? get statusLabel => model.status;

  /// Localized featured label.
  String get featuredLabel => l10n.featuredLabel;

  /// Whether to show the instructor name.
  bool get showInstructor => model.instructorName.isNotEmpty;

  /// Localized category label.
  String get categoryLabel {
    final cat = model.category;
    if (cat == null || cat.trim().isEmpty || cat.trim().toLowerCase() == 'general') {
      return l10n.generalCategory;
    }
    return cat.trim();
  }

  /// Localized level label.
  String get levelLabel {
    switch (model.level?.toLowerCase()) {
      case 'beginner':
        return l10n.levelBeginner;
      case 'intermediate':
        return l10n.levelIntermediate;
      case 'advanced':
        return l10n.levelAdvanced;
      default:
        return model.level ?? l10n.levelBeginner;
    }
  }
}
