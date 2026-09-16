import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/arb/app_localizations.dart';
// Documented architecture debt (5c): home legitimately renders the
// notifications unread badge, which is owned by the notifications feature's
// provider. There is no event/shared-model representation of an unread
// count, so this remains a direct provider import (same debt class as the
// WorkManager isolate in the downloads feature) instead of a fake seam.
import '../../../../features/notifications/application/providers/notifications_provider.dart'; // check-ignore: unread badge needs unreadCountProvider (documented debt)
import '../../../../shared/models/auth_state.dart';
import '../../../auth/application/providers/auth_provider.dart';

/// Welcome header showing personalized greeting + notification badge.
class WelcomeHeader extends ConsumerWidget {
  const WelcomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final unreadCount = ref.watch(unreadCountProvider);
    final l10n = AppLocalizations.of(context)!;
    final ds = AppColors.of(context);

    String displayName = l10n.defaultUserName;
    if (authState is AuthAuthenticated) {
      final user = authState.user;
      final name = user.firstName != null && user.lastName != null
          ? '${user.firstName} ${user.lastName}'
          : user.firstName ?? user.email.split('@').first;
      displayName = name.split(' ').first;
    }

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
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
      borderRadius: AppRadius.smBorder,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: AppRadius.smBorder,
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
