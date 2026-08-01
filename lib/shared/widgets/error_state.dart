import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 64,
          color: AppColors.error,
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text('حدث خطأ', style: AppTextStyles.h2),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'إعادة المحاولة',
            onPressed: onRetry,
            variant: AppButtonVariant.secondary,
          ),
        ],
      ],
    ),
  );
}
