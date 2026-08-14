import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

class TodoCardBase extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? background;
  final bool isCompleted;

  const TodoCardBase({
    required this.child,
    this.onTap,
    this.background,
    this.isCompleted = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);

    return AnimatedContainer(
      constraints: const BoxConstraints(minHeight: 48), // إضافة حد أدنى للارتفاع
      duration: AppMotion.medium,
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: background ?? (isCompleted ? ds.surface2 : ds.surface),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isCompleted ? ds.border.withValues(alpha: 0.5) : ds.border,
          width: isCompleted ? 0.5 : 1,
        ),
        boxShadow: isCompleted ? [] : AppElevation.shadowSm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.primary.withValues(alpha: 0.05),
          highlightColor: AppColors.primary.withValues(alpha: 0.02),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
