import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../design_system/design_system.dart';

class DiscoveryBanner extends StatelessWidget {
  const DiscoveryBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ds = AppColors.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.discoverTopPicks,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _buildDynamicCount(l10n),
                const SizedBox(height: AppSpacing.md),
                _buildExploreButton(context, l10n),
              ],
            ),
          ),
          Expanded(flex: 2, child: _buildBannerIcon(ds)),
        ],
      ),
    );
  }

  Widget _buildDynamicCount(AppLocalizations l10n) {
    final parts = l10n.plus100Courses.split(' ');
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${parts.first} ',
            style: AppTextStyles.h1.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          TextSpan(
            text: parts.skip(1).join(' '),
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExploreButton(BuildContext context, AppLocalizations l10n) {
    return ElevatedButton(
      onPressed: () => context.go(AppRoutes.discover),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
      ),
      child: Text(
        l10n.exploreMore,
        style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBannerIcon(DesignSystemColors ds) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: const Center(
        child: Icon(Icons.auto_stories_rounded, size: 64, color: Colors.white),
      ),
    );
  }
}
