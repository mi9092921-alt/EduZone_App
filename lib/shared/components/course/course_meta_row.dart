import 'package:flutter/material.dart';
import '../../../core/l10n/arb/app_localizations.dart';
import '../../../design_system/design_system.dart';
import '../../../features/courses/domain/entities/course.dart';

class CourseMetaRow extends StatelessWidget {
  final Course course;
  final AppLocalizations l10n;
  final DesignSystemColors ds;
  final String? duration;

  const CourseMetaRow({
    super.key,
    required this.course,
    required this.l10n,
    required this.ds,
    this.duration,
  });

  Widget _buildDot() {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: ds.border,
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: 4,
      children: [
        // Rating
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: AppColors.warning, size: 18),
            const SizedBox(width: 4),
            Text(
              course.ratingLabel,
              style: AppTextStyles.bodyMedium.copyWith(
                color: ds.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        _buildDot(),

        // Students
        if (course.studentsCount != null) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline_rounded,
                color: ds.textSecondary,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                course.studentsLabel,
                style: AppTextStyles.bodySmall.copyWith(
                  color: ds.textSecondary,
                ),
              ),
            ],
          ),
          _buildDot(),
        ],

        // Duration
        if (duration != null) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.access_time_rounded, color: ds.textSecondary, size: 16),
              const SizedBox(width: 4),
              Text(
                duration!,
                style: AppTextStyles.bodySmall.copyWith(color: ds.textSecondary),
              ),
            ],
          ),
          _buildDot(),
        ],

        // Level
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              color: ds.textSecondary,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              course.levelLocalized(l10n),
              style: AppTextStyles.bodySmall.copyWith(
                color: ds.textSecondary,
              ),
            ),
          ],
        ),
        
        if (course.language != null) ...[
          _buildDot(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.language_rounded,
                color: ds.textSecondary,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                course.language!.toUpperCase(),
                style: AppTextStyles.bodySmall.copyWith(
                  color: ds.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
