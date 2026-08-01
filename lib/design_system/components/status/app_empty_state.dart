import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

class AppEmptyState extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final bool isFullPage;

  const AppEmptyState({
    super.key,
    this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onActionPressed,
    this.isFullPage = true,
  });

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);
    final iconSize = isFullPage ? 64.0 : 48.0;
    
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(isFullPage ? AppSpacing.xl : 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                // Illustration Background Circle
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer subtle ring
                    Container(
                      width: iconSize * 2.2,
                      height: iconSize * 2.2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ds.primary.withValues(alpha: 0.05),
                          width: 1.5,
                        ),
                      ),
                    ),
                    // Inner circle with gradient
                    Container(
                      width: iconSize * 1.6,
                      height: iconSize * 1.6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            ds.primary.withValues(alpha: 0.12),
                            ds.primary.withValues(alpha: 0.04),
                          ],
                        ),
                      ),
                      child: Icon(
                        icon,
                        size: iconSize,
                        color: ds.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isFullPage ? AppSpacing.xl : AppSpacing.lg),
              ],

              Text(
                title,
                style: (isFullPage ? AppTextStyles.h3 : AppTextStyles.h4).copyWith(
                  color: ds.textPrimary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),

              if (description != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl2),
                  child: Text(
                    description!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: ds.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              if (actionLabel != null && onActionPressed != null) ...[
                SizedBox(height: isFullPage ? AppSpacing.xl2 : AppSpacing.xl),
                AppButton(
                  label: actionLabel!,
                  onPressed: onActionPressed,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
