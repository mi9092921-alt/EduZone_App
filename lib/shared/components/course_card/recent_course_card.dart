import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/design_system.dart';
import 'course_card_base.dart';
import 'course_card_data.dart';
import 'course_card_image.dart';
import 'course_card_progress_bar.dart';

/// Card used for "recently viewed" courses.
class RecentCourseCard extends StatelessWidget {
  final RecentCourseVM data;
  final VoidCallback? onTap;

  const RecentCourseCard({super.key, required this.data, this.onTap});

  void _defaultNavigation(BuildContext context) {
    context.push('/courses/${data.id}');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final imageWidget = courseCardImage(data.thumbnailUrl, colors);

    final contentWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.title,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
            height: 1.15,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const Spacer(),
        CourseCardProgressBar(
          progress: data.progress,
          totalLessons: data.totalLessons,
        ),
      ],
    );

    return CourseCardBase(
      image: imageWidget,
      content: contentWidget,
      semanticLabel: data.title,
      onTap: onTap ?? () => _defaultNavigation(context),
      // Taller than the 16:9 used elsewhere (was 16/9) — this card only,
      // per request to increase RecentCourseCard height without affecting
      // MyCourseCard/DiscoverCourseCard, which set their own ratios.
      verticalImageAspectRatio: 16 / 9,
      expandContent: true,
      contentPadding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
      ),
    );
  }
}
