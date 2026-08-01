import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
// AppButton is available via design_system.dart import above

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 64, color: AppColors.textSecondary),
        const SizedBox(height: AppSpacing.lg),
        Text(
          title,
          style: AppTextStyles.h2.copyWith(color: AppColors.textMuted),
        ),
        if (description != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            description!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (actionLabel != null) ...[
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: actionLabel!, onPressed: onAction),
        ],
      ],
    ),
  );
}
