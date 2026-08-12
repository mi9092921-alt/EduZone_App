import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

class TodoSwipeBackground extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final AlignmentGeometry alignment;

  const TodoSwipeBackground({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.alignment,
  });

  factory TodoSwipeBackground.edit({required String label}) {
    return TodoSwipeBackground(
      icon: AppIcons.edit,
      label: label,
      color: AppColors.primary,
      alignment: AlignmentDirectional.centerStart,
    );
  }

  factory TodoSwipeBackground.delete({required String label}) {
    return TodoSwipeBackground(
      icon: AppIcons.delete,
      label: label,
      color: AppColors.error,
      alignment: AlignmentDirectional.centerEnd,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStart = alignment == AlignmentDirectional.centerStart;

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      backgroundColor: isStart
          ? color.withValues(alpha: 0.1)
          : color.withValues(alpha: 0.8),
      borderColor: isStart ? color.withValues(alpha: 0.2) : Colors.transparent,
      elevated: false,
      borderRadius: 16,
      child: Align(
        alignment: alignment,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isStart) ...[
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Icon(icon, color: isStart ? color : Colors.white, size: 24),
            if (isStart) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
