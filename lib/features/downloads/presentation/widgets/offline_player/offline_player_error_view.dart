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

  /// When true, [errorMessage] is shown regardless of build mode. Set this
  /// only when the caller has already verified the message is safe for end
  /// users (no paths/ids/internal state) — e.g. `OfflinePlaybackDeniedException
  /// .userMessage`. Defaults to false, preserving the previous
  /// debug-only behavior for ordinary (developer-facing) exception text.
  final bool alwaysShowMessage;

  const OfflinePlayerErrorView({
    super.key,
    required this.aspectRatio,
    required this.errorMessage,
    required this.onRetry,
    this.alwaysShowMessage = false,
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
              // implementation details, so it stays gated behind
              // kDebugMode. `alwaysShowMessage` is the one deliberate
              // exception: callers set it only when errorMessage has
              // already been vetted as end-user-safe (see
              // OfflinePlaybackDeniedException.userMessage).
              if ((kDebugMode || alwaysShowMessage) && errorMessage != null) ...[
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
