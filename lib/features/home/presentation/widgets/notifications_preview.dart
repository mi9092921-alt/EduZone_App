import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../shared/cross_feature/notifications_shared.dart';

class NotificationsPreview extends ConsumerWidget {
  const NotificationsPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final l10n = AppLocalizations.of(context);

    return notificationsAsync.when(
      data: (notifications) {
        final unreadNotifications = notifications
            .where((n) => !n.isRead)
            .take(2)
            .toList();
        if (unreadNotifications.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n!.notificationsTitle,
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (unreadNotifications.isNotEmpty)
                    Text(
                      '${unreadNotifications.length} ${l10n.notificationsTitle}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: unreadNotifications
                    .map((n) => NotificationTile(notification: n))
                    .toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        );
      },
      loading: () =>
          const SizedBox.shrink(), // Silent loading for dash consistency
      error: (e, s) {
        debugPrint('[NotificationsPreview] Error: ${e.runtimeType}');
        return const SizedBox.shrink();
      },
    );
  }
}
