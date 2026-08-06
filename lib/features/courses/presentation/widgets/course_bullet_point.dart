import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// A single checkmark + text row, used for "What you'll learn" and
/// "Prerequisites" lists.
///
/// Extracted from the duplicated `_buildBulletPoint` methods that used to
/// live identically in both `CourseDetailsScreen` and `CoursePreviewScreen`.
class CourseBulletPoint extends StatelessWidget {
  final DesignSystemColors ds;
  final String text;

  const CourseBulletPoint({super.key, required this.ds, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(color: ds.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
