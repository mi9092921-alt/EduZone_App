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
    // Watched (not just read) so the autoDispose submit notifier stays alive
    // for the whole in-flight submission — a read-only notifier has no
    // listeners and Riverpod may dispose it mid-round-trip, losing the
    // final success/error state the tap handler reports on.
    ref.watch(courseRatingSubmitProvider);
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

  Future<bool> _submitRating(
    BuildContext context,
    WidgetRef ref,
    int value,
  ) async {
    final hadPreviousRating =
        (ref.read(myCourseRatingProvider(course.id)).value ?? 0) > 0;
    final submit = ref.read(courseRatingSubmitProvider.notifier);
    await submit.submit(course.id, value);

    final submitState = ref.read(courseRatingSubmitProvider);
    if (!context.mounted) return false;
    // Error takes precedence: under Riverpod 3 an AsyncError set after a
    // previous AsyncData still reports hasValue (it carries the previous
    // value), so checking hasValue first misreports failures as success.
    if (submitState.hasError) {
      FeedbackService.show(
        context,
        message: l10n.ratingSubmitFailed,
        type: FeedbackType.error,
      );
      return false;
    }
    FeedbackService.show(
      context,
      message: hadPreviousRating ? l10n.ratingUpdated : l10n.ratingSubmitted,
      type: FeedbackType.success,
    );
    return true;
  }
}

/// The tappable 1–5 star row. Submission happens on tap (no separate
/// confirm button) — matching the one-tap rating pattern of most
/// store-style UIs; a re-tap updates the rating.
///
/// The tapped value is shown optimistically: the star lights up on the tap
/// itself instead of waiting for the `rate_course` round-trip and the
/// `myCourseRating` re-fetch to come back. The local override is dropped as
/// soon as the provider reports a (different) value, and reverted if the
/// submit fails.
class _RatingStars extends StatefulWidget {
  final int? currentRating;

  /// Returns `true` when the submission succeeded, so the optimistic star
  /// can be kept (it matches what the provider will report) or reverted.
  final Future<bool> Function(int) onSubmit;
  final AppLocalizations l10n;

  const _RatingStars({
    required this.currentRating,
    required this.onSubmit,
    required this.l10n,
  });

  @override
  State<_RatingStars> createState() => _RatingStarsState();
}

class _RatingStarsState extends State<_RatingStars> {
  int? _optimisticRating;

  @override
  void didUpdateWidget(covariant _RatingStars oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Server state moved on (re-fetch completed) — defer to it.
    if (widget.currentRating != oldWidget.currentRating &&
        _optimisticRating != null) {
      _optimisticRating = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _optimisticRating ?? widget.currentRating ?? 0;
    return Row(
      children: [
        for (var star = 1; star <= 5; star++)
          AppIconButton(
            key: ValueKey('rating_star_$star'),
            icon: star <= selected
                ? Icons.star_rounded
                : Icons.star_outline_rounded,
            color: AppColors.warning,
            iconSize: 32,
            semanticLabel: widget.l10n.ratingStarTooltip(star),
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () => _onStarTap(star),
          ),
      ],
    );
  }

  Future<void> _onStarTap(int star) async {
    setState(() => _optimisticRating = star);
    final success = await widget.onSubmit(star);
    if (!success && mounted && _optimisticRating == star) {
      setState(() => _optimisticRating = null);
    }
  }
}
