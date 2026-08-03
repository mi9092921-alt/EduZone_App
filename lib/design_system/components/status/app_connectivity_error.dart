import 'package:flutter/material.dart';
import '../../design_system.dart';

class AppConnectivityError extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final bool isFullPage;
  final bool isLoading;

  const AppConnectivityError({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.isFullPage = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);
    final sizeMultiplier = isFullPage ? 1.0 : 0.7;

    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: child,
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(isFullPage ? AppSpacing.xl : AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Layered Icon Container
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120 * sizeMultiplier,
                    height: 120 * sizeMultiplier,
                    decoration: BoxDecoration(
                      color: ds.error.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 90 * sizeMultiplier,
                    height: 90 * sizeMultiplier,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.topStart,
                        end: AlignmentDirectional.bottomEnd,
                        colors: [
                          ds.error.withValues(alpha: 0.2),
                          ds.error.withValues(alpha: 0.1),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.wifi_off_rounded,
                      size: 40 * sizeMultiplier,
                      color: ds.error,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.lg * sizeMultiplier),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.h3.copyWith(
                  fontSize: (AppTextStyles.h3.fontSize ?? 24) * sizeMultiplier,
                  color: ds.textPrimary,
                ),
              ),
              SizedBox(height: AppSpacing.xs * sizeMultiplier),

              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: ds.textPrimary.withValues(alpha: 0.6),
                  fontSize:
                      (AppTextStyles.bodyMedium.fontSize ?? 16) *
                      sizeMultiplier,
                ),
              ),
              SizedBox(height: AppSpacing.xl * sizeMultiplier),

              // Retry Button
              SizedBox(
                width: isFullPage ? double.infinity : 160,
                child: AppButton(
                  label: 'Retry',
                  onPressed: onRetry,
                  isLoading: isLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
