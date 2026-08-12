import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onTrailingTapped;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.onTrailingTapped,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppTextStyles.h3.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.of(context).textPrimary,
            ),
          ),
          if (trailing != null)
            InkWell(
              onTap: onTrailingTapped,
              borderRadius: AppRadius.xxsBorder,
              child: trailing!,
            ),
        ],
      ),
    );
  }
}
