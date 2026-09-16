import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/text_direction_detector.dart';
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
    final ds = AppColors.of(context);
    final progressValue = (lesson.progressPct / 100).clamp(0.0, 1.0);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
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
                    lesson.lessonTitle,
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.bold,
                      color: ds.textPrimary,
                    ),
                    textDirection:
                        TextDirectionDetector.detect(lesson.lessonTitle),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    lesson.courseTitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: ds.textSecondary,
                    ),
                    textDirection:
                        TextDirectionDetector.detect(lesson.courseTitle),
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
          const SizedBox(width: AppSpacing.md),
          AppIconContainer(
            icon: Icons.play_arrow_rounded,
            size: 28,
            backgroundColor: AppColors.primary,
            iconColor: ds.surface,
            padding: AppSpacing.md,
          ),
        ],
      ),
    );
  }
}
