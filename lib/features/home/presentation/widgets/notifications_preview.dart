import 'package:app/design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../shared/components/notification_tile.dart';
import '../../../../shared/providers/home_notifications_gateway.dart';
import '../../../../shared/utils/error_handler.dart';
import '../../../../shared/widgets/error_state.dart';

class NotificationsPreview extends ConsumerWidget {
  const NotificationsPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Cross-feature seam: notifications state is read through the shared
    // gateway contract (implemented by the notifications feature, injected
    // at the composition root) instead of importing that feature directly.
    final gateway = ref.watch(homeNotificationsGatewayProvider);
    if (gateway == null) return const SizedBox.shrink();
    final notificationsAsync = ref.watch(gateway.notifications);
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
                    .map((n) => NotificationTile(
                          notification: n,
                          onMarkAsRead: () async {
                            final success = await gateway.markAsRead(
                              notificationId: n.id,
                              userId: n.userId,
                            );
                            if (success) gateway.refresh();
                          },
                        ))
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
        // Phase 10: was a silent SizedBox.shrink() — a failed notifications
        // fetch was indistinguishable from "no notifications", the exact
        // error→empty masking the codebase already reclassified as a P1
        // pattern for the resume section. Show the same retryable error
        // state the sibling sections use; loading stays silent.
        if (kDebugMode) {
          debugPrint('[NotificationsPreview] Error: ${e.runtimeType}');
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: ErrorState(
            message: ErrorHandler.getMessage(context, e),
            onRetry: () => gateway.refresh(),
          ),
        );
      },
    );
  }
}
