import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, danger, ghost, gradient }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? leadingIcon;
  final double? width;
  final double? height;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.leadingIcon,
    this.width,
    this.height,
  });

  Widget _buildContent(BuildContext context, Color color) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
    }

    if (leadingIcon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(leadingIcon, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text(label),
        ],
      );
    }
    return Text(label);
  }

  @override
  Widget build(BuildContext context) {
    // Determine action. If loading, button shouldn't be clickable.
    final action = isLoading ? null : onPressed;

    Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
        button = ElevatedButton(
          onPressed: action,
          child: _buildContent(context, Colors.white),
        );
        break;
      case AppButtonVariant.secondary:
        button = OutlinedButton(
          onPressed: action,
          child: _buildContent(context, AppColors.primary),
        );
        break;
      case AppButtonVariant.danger:
        button = ElevatedButton(
          onPressed: action,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: _buildContent(context, Colors.white),
        );
        break;
      case AppButtonVariant.ghost:
        button = TextButton(
          onPressed: action,
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          child: _buildContent(context, AppColors.primary),
        );
        break;
      case AppButtonVariant.gradient:
        button = DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: AppRadius.smBorder,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: action,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
            ),
            child: _buildContent(context, Colors.white),
          ),
        );
        break;
    }

    if (width != null || height != null) {
      return SizedBox(width: width, height: height, child: button);
    }
    return button;
  }
}
