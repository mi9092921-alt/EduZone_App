import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

class AppIconContainer extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final double size;
  final double padding;

  const AppIconContainer({
    super.key,
    required this.icon,
    this.iconColor,
    this.backgroundColor,
    this.size = 20,
    this.padding = AppSpacing.sm,
  });

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: backgroundColor ?? ds.surface2,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: ds.border.withValues(alpha: 0.2)),
      ),
      child: Icon(icon, size: size, color: iconColor ?? AppColors.primary),
    );
  }
}
