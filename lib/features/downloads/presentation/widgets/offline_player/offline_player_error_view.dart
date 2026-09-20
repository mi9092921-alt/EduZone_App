import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../../../../core/l10n/arb/app_localizations.dart';
import '../../../../../design_system/design_system.dart';
import '../../../application/services/offline_policy_engine.dart';

/// Localized, release-safe wording for every
/// [OfflinePlaybackDenialReason]. The application layer hands the UI a
/// reason enum only — all end-user text lives in the l10n ARB files (the
/// previous hardcoded English strings on the exception violated the
/// project's i18n rule and showed English copy to ar-EG users).
String offlineDenialMessage(
  AppLocalizations l10n,
  OfflinePlaybackDenialReason reason,
) {
  switch (reason) {
    case OfflinePlaybackDenialReason.downloadNotFound:
      return l10n.offlineDenialDownloadNotFound;
    case OfflinePlaybackDenialReason.tampered:
      return l10n.offlineDenialTampered;
    case OfflinePlaybackDenialReason.notCompleted:
      return l10n.offlineDenialNotCompleted;
    case OfflinePlaybackDenialReason.expired:
      return l10n.offlineDenialExpired;
    case OfflinePlaybackDenialReason.ownerMismatch:
      return l10n.offlineDenialOwnerMismatch;
    case OfflinePlaybackDenialReason.deviceMismatch:
      return l10n.offlineDenialDeviceMismatch;
    case OfflinePlaybackDenialReason.missingFile:
      return l10n.offlineDenialMissingFile;
    case OfflinePlaybackDenialReason.missingKey:
      return l10n.offlineDenialMissingKey;
    case OfflinePlaybackDenialReason.clockRollbackSuspected:
      return l10n.offlineDenialClockRollback;
    case OfflinePlaybackDenialReason.serverRevalidationDenied:
      return l10n.offlineDenialServerDenied;
  }
}

/// Error state shown when initialization (decryption / proxy start /
/// player open) fails, with a retry action.
///
/// Pure presentational widget driven entirely by [denialReason] /
/// [errorMessage] and [onRetry] — no dependency on the player or
/// decryption service, so it is fully unit-testable in isolation.
class OfflinePlayerErrorView extends StatelessWidget {
  final double aspectRatio;

  /// When set, the view renders the localized, release-safe wording for
  /// this offline-playback denial reason (see [offlineDenialMessage]) —
  /// regardless of build mode, because ARB-sourced copy is vetted for end
  /// users by construction. [errorMessage] is then ignored.
  final OfflinePlaybackDenialReason? denialReason;

  /// Developer-facing detail (e.g. a raw exception message). Shown ONLY in
  /// debug builds — raw exception text can leak paths/ids/internal state,
  /// so it must never reach release UI.
  final String? errorMessage;
  final VoidCallback onRetry;

  const OfflinePlayerErrorView({
    super.key,
    required this.aspectRatio,
    this.denialReason,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    final localizedDenial =
        denialReason == null ? null : offlineDenialMessage(l10n, denialReason!);

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
              // Localized denial wording is release-safe by construction
              // (ARB-sourced, no paths/ids), so it renders in every build
              // mode. Raw exception text is developer-facing detail and
              // stays gated behind kDebugMode.
              if (localizedDenial != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  localizedDenial,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: ds.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else if (kDebugMode && errorMessage != null) ...[
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
