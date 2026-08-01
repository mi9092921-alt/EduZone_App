import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

/// Welcome header showing personalized greeting + notification badge.
class WelcomeHeader extends ConsumerWidget {
  const WelcomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final unreadCount = ref.watch(unreadCountProvider);
    final l10n = AppLocalizations.of(context)!;
    final ds = AppColors.of(context);

    final displayName = profile.when(
      data: (p) => p.displayName.split(' ').first,
      loading: () => l10n.defaultUserName,
      error: (_, _) => l10n.defaultUserName,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.welcome_user(displayName),
                  style: AppTextStyles.h1.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.findLessons,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: ds.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          _buildNotificationIcon(context, unreadCount, ds),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon(
    BuildContext context,
    int unreadCount,
    DesignSystemColors ds,
  ) {
    final icon = Icon(
      AppIcons.notifications,
      color: unreadCount > 0 ? AppColors.primary : ds.textSecondary,
      size: 28,
    );

    return InkWell(
      onTap: () => context.push('${AppRoutes.home}/notifications'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: unreadCount > 0
            ? Badge(
                label: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: AppColors.error,
                child: icon,
              )
            : icon,
      ),
    );
  }
}
