import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/design_system.dart';
import 'course_card_base.dart';
import 'course_card_data.dart';
import 'course_card_image.dart';
import 'course_card_progress_bar.dart';

/// Card used on the "My Courses" screen.
class MyCourseCard extends StatelessWidget {
  final MyCourseVM data;
  final bool isHorizontal;
  final VoidCallback? onTap;

  const MyCourseCard({
    super.key,
    required this.data,
    this.isHorizontal = false,
    this.onTap,
  });

  void _defaultNavigation(BuildContext context) {
    context.push('/courses/${data.id}');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final imageWidget = courseCardImage(
      data.thumbnailUrl,
      colors,
      context: context,
    );

    final contentWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.title,
          style: (isHorizontal ? AppTextStyles.bodyMedium : AppTextStyles.h4)
              .copyWith(
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
      isHorizontal: isHorizontal,
      semanticLabel: data.title,
      onTap: onTap ?? () => _defaultNavigation(context),
      verticalImageAspectRatio: 16 / 9,
      horizontalHeight: 80,
      // Square thumbnail in the horizontal layout (width == height) for
      // the My Courses list.
      horizontalImageWidth: 80,
      contentPadding: isHorizontal
          ? const EdgeInsetsDirectional.fromSTEB(
              0,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.xs,
            )
          : const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.sm,
              0,
              AppSpacing.sm,
              AppSpacing.md,
            ),
    );
  }
}
