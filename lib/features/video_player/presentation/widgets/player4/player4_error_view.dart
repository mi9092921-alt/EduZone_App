import 'package:flutter/material.dart';

import '../../../../../core/l10n/arb/app_localizations.dart';
import '../../../../../design_system/design_system.dart';

/// Full-bleed error state with a retry action, shown when video
/// fetch/playback fails and no more automatic retries are left.
///
/// Pure presentational widget driven entirely by [errorMessage] and
/// [onRetry] — no dependency on the player or providers, so it is fully
/// unit-testable in isolation.
class Player4ErrorView extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;

  const Player4ErrorView({
    super.key,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      color: Colors.black.withValues(alpha: 0.96),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, color: ds.error, size: 40),
            const SizedBox(height: AppSpacing.md),
            Text(
              errorMessage,
              style: AppTextStyles.bodyMedium.copyWith(
                color: ds.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ds.surface2,
                foregroundColor: ds.primary,
                elevation: 0,
                side: BorderSide(color: ds.primary.withValues(alpha: 0.4)),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.mdBorder,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                l10n.retryLoading,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
