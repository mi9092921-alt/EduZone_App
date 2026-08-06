import 'package:flutter/material.dart';

import '../../../core/l10n/arb/app_localizations.dart';
import '../../../design_system/design_system.dart';

/// Progress bar + "x/y lessons" status row shared by [MyCourseCard] and
/// [RecentCourseCard].
class CourseCardProgressBar extends StatelessWidget {
  final double progress;
  final int totalLessons;

  const CourseCardProgressBar({
    super.key,
    required this.progress,
    required this.totalLessons,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    final safeProgress = progress.clamp(0.0, 1.0);
    final isCompleted = safeProgress >= 1.0;
    final completedLessons = isCompleted
        ? totalLessons
        : (safeProgress * totalLessons).round().clamp(0, totalLessons);
    final statusColor = isCompleted ? colors.success : colors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppProgressBar(progress: safeProgress),
        const SizedBox(height: AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              isCompleted ? l10n.completed : '${(safeProgress * 100).round()}%',
              style: AppTextStyles.labelSmall.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            Icon(
              isCompleted ? Icons.check_circle : Icons.play_circle_outline,
              size: 13,
              color: isCompleted ? colors.success : colors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs2),
            Text(
              l10n.lessonsProgress(completedLessons, totalLessons),
              style: AppTextStyles.labelSmall.copyWith(
                color: colors.textSecondary,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }
}
