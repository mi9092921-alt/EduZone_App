import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/feature_flags/feature_flag_keys.dart';
import '../../../../core/feature_flags/feature_flags_provider.dart';
import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/models/course.dart';
import '../../../../shared/utils/app_snackbar.dart';
import '../../application/providers/courses_provider.dart';

/// Aggregate + interactive star rating for a course, rendered on the
/// "About" tab of both the preview and details screens (inserted by
/// `buildCourseAboutTabContent`).
///
/// Display (average + count) is always shown; the tappable input is gated
/// by [FeatureFlagKey.courseRating] and by enrollment state — the
/// `rate_course` RPC enforces both server-side regardless, so this is UX
/// gating, not an authorization boundary.
class CourseRatingSection extends ConsumerWidget {
  final Course course;
  final AppLocalizations l10n;
  final DesignSystemColors ds;

  const CourseRatingSection({
    super.key,
    required this.course,
    required this.l10n,
    required this.ds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratingInputEnabled = ref
        .watch(featureFlagsProvider)
        .isEnabled(FeatureFlagKey.courseRating);
    final isEnrolled = ref.watch(isEnrolledProvider(course.id));
    final canRate =
        ratingInputEnabled && isEnrolled.hasValue && isEnrolled.value == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.ratingSectionTitle, style: AppTextStyles.h3),
        const SizedBox(height: AppSpacing.md),
        _buildAggregateRow(),
        if (canRate) ...[
          const SizedBox(height: AppSpacing.md),
          _RatingStars(
            currentRating: ref.watch(myCourseRatingProvider(course.id)).value,
            onSubmit: (value) => _submitRating(context, ref, value),
            l10n: l10n,
          ),
        ] else if (ratingInputEnabled &&
            isEnrolled.hasValue &&
            isEnrolled.value == false) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.ratingNotEnrolled,
            style: AppTextStyles.bodySmall.copyWith(
              color: ds.textMuted,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAggregateRow() {
    final rating = course.rating;
    final hasRating = rating != null && rating > 0;
    return Row(
      children: [
        Icon(
          Icons.star_rounded,
          size: 20,
          color: hasRating ? AppColors.warning : ds.border,
        ),
        const SizedBox(width: AppSpacing.xs2),
        Text(
          hasRating ? rating.toStringAsFixed(1) : '—',
          style: AppTextStyles.bodyLarge.copyWith(
            color: ds.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          l10n.ratingsCountLabel(course.ratingCount ?? 0),
          style: AppTextStyles.bodySmall.copyWith(color: ds.textSecondary),
        ),
      ],
    );
  }

  Future<void> _submitRating(
    BuildContext context,
    WidgetRef ref,
    int value,
  ) async {
    final hadPreviousRating =
        (ref.read(myCourseRatingProvider(course.id)).value ?? 0) > 0;
    final submit = ref.read(courseRatingSubmitProvider.notifier);
    await submit.submit(course.id, value);

    final submitState = ref.read(courseRatingSubmitProvider);
    if (!context.mounted) return;
    if (submitState.hasValue) {
      FeedbackService.show(
        context,
        message:
            hadPreviousRating ? l10n.ratingUpdated : l10n.ratingSubmitted,
        type: FeedbackType.success,
      );
    } else if (submitState.hasError) {
      FeedbackService.show(
        context,
        message: l10n.ratingSubmitFailed,
        type: FeedbackType.error,
      );
    }
  }
}

/// The tappable 1–5 star row. Submission happens on tap (no separate
/// confirm button) — matching the one-tap rating pattern of most
/// store-style UIs; a re-tap updates the rating.
class _RatingStars extends StatelessWidget {
  final int? currentRating;
  final ValueChanged<int> onSubmit;
  final AppLocalizations l10n;

  const _RatingStars({
    required this.currentRating,
    required this.onSubmit,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final selected = currentRating ?? 0;
    return Row(
      children: [
        for (var star = 1; star <= 5; star++)
          IconButton(
            key: ValueKey('rating_star_$star'),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Icon(
              star <= selected
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              size: 32,
              color: AppColors.warning,
            ),
            tooltip: l10n.ratingStarTooltip(star),
            onPressed: () => onSubmit(star),
          ),
      ],
    );
  }
}
