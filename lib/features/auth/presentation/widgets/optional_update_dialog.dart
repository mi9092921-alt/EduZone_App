import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/arb/app_localizations.dart';
import '../../domain/entities/update_info.dart';

/// Shows a non-blocking update dialog once per version.
///
/// Persistence: uses [StorageKeys.lastDismissedUpdateVersion] so the dialog
/// appears only once for a given [UpdateInfo.latestVersion].
///
/// Usage (from HomeScreen.initState / WidgetsBinding.instance.addPostFrameCallback):
/// ```dart
/// OptionalUpdateDialog.maybeShow(context, updateInfo);
/// ```
class OptionalUpdateDialog {
  OptionalUpdateDialog._();

  /// Entry point — checks persistence then shows the dialog if appropriate.
  static Future<void> maybeShow(BuildContext context, UpdateInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getString(StorageKeys.lastDismissedUpdateVersion);

    // Already dismissed for this version — skip
    if (dismissed == info.latestVersion) return;

    // Context might have become invalid during the await
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false, // Force explicit choice (Later / Update)
      builder: (ctx) => _OptionalUpdateDialogContent(info: info),
    );
  }
}

class _OptionalUpdateDialogContent extends StatelessWidget {
  final UpdateInfo info;

  const _OptionalUpdateDialogContent({required this.info});

  Future<void> _dismiss(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StorageKeys.lastDismissedUpdateVersion,
      info.latestVersion,
    );
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _openStore() async {
    if (info.storeUrl.isEmpty) return;
    final uri = Uri.tryParse(info.storeUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ds = AppColors.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Gradient header ────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xl,
              horizontal: AppSpacing.lg,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryPressed],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.new_releases_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.optionalUpdateTitle,
                  style: AppTextStyles.h2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.versionLabel(info.latestVersion),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                if (info.message.isNotEmpty)
                  Text(
                    info.message,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: ds.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                const SizedBox(height: AppSpacing.xl),

                // Update Now button
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: l10n.optionalUpdateBtn,
                    leadingIcon: Icons.download_rounded,
                    onPressed: _openStore,
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                // Later button
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: l10n.optionalUpdateLater,
                    variant: AppButtonVariant.ghost,
                    onPressed: () => _dismiss(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
