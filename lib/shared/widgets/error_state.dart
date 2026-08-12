import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../core/l10n/arb/app_localizations.dart';

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: AppColors.error,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.errorGeneric, style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: l10n.retryButton,
              onPressed: onRetry,
              variant: AppButtonVariant.secondary,
            ),
          ],
        ],
      ),
    );
  }
}
