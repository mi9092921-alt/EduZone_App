import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../application/providers/auth_provider.dart';
import '../../domain/entities/auth_state.dart';

/// Full-screen update gate — shown when [AppAuthState.forceUpdate] is active.
///
/// Mirrors the pattern of [BannedScreen] and [MaintenanceScreen]:
/// - No back button, no dismiss, no logout (user MUST update)
/// - [updateInfo] is read from the sealed [AuthState] — not passed via constructor
/// - Store URL is resolved server-side (platform-aware in [UpdateService])
class ForceUpdateScreen extends ConsumerWidget {
  const ForceUpdateScreen({super.key});

  Future<void> _openStore(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final ds = AppColors.of(context);

    // Read updateInfo from the sealed AuthState
    final authState = ref.watch(authProvider);
    final updateInfo = authState is AuthForceUpdate
        ? authState.updateInfo
        : null;

    final message = (updateInfo?.message.isNotEmpty == true)
        ? updateInfo!.message
        : l10n.forceUpdateMsg;

    final storeUrl = updateInfo?.storeUrl ?? '';

    return AppScreen(
      scrollable: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Icon ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  size: 64,
                  color: AppColors.warning,
                ),
              ),

              const SizedBox(height: AppSpacing.xl2),

              // ── Title ──────────────────────────────────────────────
              Text(
                l10n.forceUpdateTitle,
                style: AppTextStyles.h1.copyWith(
                  color: ds.warningText,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Server message ─────────────────────────────────────
              Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: ds.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xl3),

              // ── Update CTA ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: l10n.forceUpdateBtn,
                  leadingIcon: Icons.download_rounded,
                  onPressed: storeUrl.isNotEmpty
                      ? () => _openStore(storeUrl)
                      : null,
                ),
              ),

              // ── Version hint ───────────────────────────────────────
              if (updateInfo != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.versionLabel(updateInfo.latestVersion),
                  style: AppTextStyles.bodySmall.copyWith(color: ds.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
