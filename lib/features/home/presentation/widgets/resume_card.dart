import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../shared/widgets/app_icon_container.dart';
import '../../domain/entities/resume_lesson.dart';

class ResumeCard extends StatelessWidget {
  final ResumeLesson? resumeLesson;
  final bool isLoading;

  const ResumeCard({super.key, this.resumeLesson, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return AppSkeleton(
        child: _buildMainContent(context, ResumeLesson.skeleton()),
      );
    }

    if (resumeLesson == null) {
      return const SizedBox.shrink();
    }

    return _buildMainContent(context, resumeLesson!);
  }

  Widget _buildMainContent(BuildContext context, ResumeLesson lesson) {
    final l10n = AppLocalizations.of(context);
    final ds = AppColors.of(context);
    final progressValue = (lesson.progressPct / 100).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        onTap: isLoading
            ? null
            : () {
                context.push(
                  '${AppRoutes.courses}/${lesson.courseId}/lesson/${lesson.lessonId}',
                );
              },
        gradient: LinearGradient(
          colors: [ds.surface2, ds.surface],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderColor: ds.border.withValues(alpha: 0.5),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n!.continue_learning,
                    style: AppTextStyles.overline.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    lesson.lessonTitle,
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.bold,
                      color: ds.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    lesson.courseTitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: ds.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                          child: LinearProgressIndicator(
                            value: progressValue,
                            backgroundColor: AppColors.primary.withValues(
                              alpha: 0.1,
                            ),
                            color: AppColors.primary,
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${lesson.progressPct.toInt()}%',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            AppIconContainer(
              icon: Icons.play_arrow_rounded,
              size: 28,
              backgroundColor: AppColors.primary,
              iconColor: ds.surface,
              padding: AppSpacing.md,
            ),
          ],
        ),
      ),
    );
  }
}
