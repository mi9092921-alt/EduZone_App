import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/course.dart';
import '../utils/course_format_utils.dart';

class CourseCurriculumPreview extends StatelessWidget {
  final Course course;
  final DesignSystemColors ds;
  final AppLocalizations l10n;

  const CourseCurriculumPreview({
    super.key,
    required this.course,
    required this.ds,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    if (course.sections == null || course.sections!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.courseCurriculumLabel,
          style: AppTextStyles.h3.copyWith(
            fontWeight: FontWeight.bold,
            color: ds.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${course.sections?.length ?? 0} ${l10n.sectionsLabel} • ${l10n.lessonsCount(course.totalLessons ?? course.computedTotalLessons)} • ${formatCourseDuration(course.totalDurationMinutes, l10n)}',
          style: AppTextStyles.bodySmall.copyWith(color: ds.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: course.sections!.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final section = course.sections![index];
            final lessons = section.lessons ?? [];

            return DecoratedBox(
              decoration: BoxDecoration(
                color: ds.surface2,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: ds.border),
              ),
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(
                    section.title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: ds.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    l10n.lessonsCount(lessons.length),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: ds.textSecondary,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.only(
                    bottom: AppSpacing.sm,
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                  ),
                  children: lessons.map((lesson) {
                    final canPreview = lesson.isPreview;

                    return InkWell(
                      onTap: canPreview
                          ? () => context.push(
                              '/courses/${course.id}/lesson/${lesson.id}',
                            )
                          : null,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              canPreview
                                  ? Icons.play_circle_fill_rounded
                                  : Icons.lock_outline_rounded,
                              size: 16,
                              color: canPreview
                                  ? AppColors.success
                                  : ds.textMuted,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                lesson.title,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: canPreview
                                      ? ds.textPrimary
                                      : ds.textSecondary,
                                  fontWeight: canPreview
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (canPreview)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  l10n.freeLabel,
                                  style: const TextStyle(
                                    color: AppColors.success,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
