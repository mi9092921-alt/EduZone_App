import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';

/// Frosted-glass pill used for the level badge and the "new" badge overlaid
/// on top of a course thumbnail.
///
/// Exposed (not `_`-prefixed) because it is used from both
/// `discover_course_card.dart` (level badge + "new" badge) — i.e. across
/// more than one file in this feature folder. It is intentionally not
/// re-exported from the public `course_card.dart` barrel or the design
/// system, so it stays private to `lib/shared/components/course_card/`.
class CourseCardOverlayBadge extends StatelessWidget {
  final Widget child;
  final Color? tint;

  const CourseCardOverlayBadge({super.key, required this.child, this.tint});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final badgeColor = tint ?? colors.surface;
    final borderColor = tint ?? colors.border;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: AppSpacing.xs, sigmaY: AppSpacing.xs),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: borderColor.withValues(alpha: 0.32)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs2,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
