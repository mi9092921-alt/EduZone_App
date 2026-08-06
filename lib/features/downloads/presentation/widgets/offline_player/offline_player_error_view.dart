import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../../../../core/l10n/arb/app_localizations.dart';
import '../../../../../design_system/design_system.dart';

/// Error state shown when initialization (decryption / proxy start /
/// player open) fails, with a retry action.
///
/// Pure presentational widget driven entirely by [errorMessage] and
/// [onRetry] — no dependency on the player or decryption service, so it is
/// fully unit-testable in isolation.
class OfflinePlayerErrorView extends StatelessWidget {
  final double aspectRatio;
  final String? errorMessage;
  final VoidCallback onRetry;

  const OfflinePlayerErrorView({
    super.key,
    required this.aspectRatio,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ColoredBox(
        color: ds.surface2,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: ds.error),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.errorGeneric,
                style: AppTextStyles.h4.copyWith(color: ds.textPrimary),
              ),
              // Raw exception text is developer-facing detail; showing it to
              // end users in release builds isn't useful and can leak
              // implementation details. Only surface it in debug builds.
              if (kDebugMode && errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  errorMessage!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: ds.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              TextButton.icon(
                onPressed: onRetry,
                icon: Icon(Icons.refresh_rounded, color: ds.primary),
                label: Text(
                  l10n.downloadRetry,
                  style: AppTextStyles.bodyMedium.copyWith(color: ds.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
