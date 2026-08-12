import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/arb/app_localizations.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ds = AppColors.of(context);

    final isTerms = type == 'terms';
    final title = isTerms ? l10n.termsAndConditions : l10n.privacyPolicy;
    final content = isTerms ? l10n.termsContent : l10n.privacyContent;

    return AppPageScaffold(
      title: title,
      centerTitle: true,
      leading: AppIconButton(
        icon: AppIcons.back,
        iconSize: 24,
        color: ds.textPrimary,
        semanticLabel: l10n.navigateBack,
        onPressed: () => Navigator.of(context).pop(),
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                boxShadow: AppShadows.level2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isTerms
                            ? Icons.description_rounded
                            : Icons.security_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    title,
                    style: AppTextStyles.h2.copyWith(
                      color: ds.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.lastUpdated('April 2026'),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: ds.textSecondary,
                    ),
                  ),
                  const Divider(height: AppSpacing.xl),
                  Text(
                    content,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: ds.textPrimary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: Text(
                      l10n.copyright(DateTime.now().year.toString()),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: ds.textSecondary.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
