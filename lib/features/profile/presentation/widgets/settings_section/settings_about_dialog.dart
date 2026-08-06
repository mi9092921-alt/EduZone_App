import 'package:flutter/material.dart';

import '../../../../../core/l10n/arb/app_localizations.dart';
import '../../../../../design_system/design_system.dart';
import 'settings_floating_graduation_icon.dart';

/// Opens the "About" dialog showing the app icon, name, [version], tagline,
/// and copyright line.
void showSettingsAboutDialog(BuildContext context, String version) {
  showDialog(
    context: context,
    builder: (dialogContext) => SettingsAboutDialog(version: version),
  );
}

/// Content of the "About" dialog. Pure presentational widget — all data
/// (the pre-formatted [version] string) is passed in, so it's independently
/// testable.
class SettingsAboutDialog extends StatelessWidget {
  final String version;

  const SettingsAboutDialog({super.key, required this.version});

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      backgroundColor: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const SettingsFloatingGraduationIcon(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.appTitle,
              style: AppTextStyles.h2.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              version,
              style: AppTextStyles.bodyMedium.copyWith(
                color: ds.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.modernLearningPlatform,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: ds.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.copyrightFull(DateTime.now().year.toString()),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: ds.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: l10n.ok,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
