import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../domain/entities/app_notification.dart';
import '../../application/providers/notifications_provider.dart';

class NotificationTile extends ConsumerWidget {
  final AppNotification notification;

  const NotificationTile({super.key, required this.notification});

  void _markAsRead(WidgetRef ref) {
    if (!notification.isRead) {
      ref.read(markAsReadProvider).call(notification.id, notification.userId);
    }
  }

  void _showDetails(BuildContext context, WidgetRef ref) {
    _markAsRead(ref);

    final ds = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return AppCard(
          margin: const EdgeInsets.all(AppSpacing.md),
          backgroundColor: ds.surface,
          borderColor: ds.surface2,
          borderRadius: 16,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: Material(
                        color: ds.border.withValues(alpha: 0.5),
                        borderRadius: AppRadius.hairlineBorder,
                        child: const SizedBox(width: 40, height: 4),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
                        elevated: false,
                        borderRadius: 8,
                        child: const Icon(
                          AppIcons.notification,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          notification.title,
                          style: AppTextStyles.h3.copyWith(
                            fontWeight: FontWeight.bold,
                            color: ds.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    notification.body,
                    style: AppTextStyles.bodyLarge.copyWith(
                      height: 1.6,
                      color: ds.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    timeago.format(
                      notification.createdAt,
                      locale: Localizations.localeOf(context).languageCode,
                    ),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: ds.textMuted,
                    ),
                    textAlign: TextAlign.end,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ds.surface2,
                      foregroundColor: ds.textPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.mdBorder,
                        side: BorderSide(color: ds.border),
                      ),
                    ),
                    child: Text(AppLocalizations.of(context)!.closeButton),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = AppColors.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context)!;

    // Determine type-based styling
    final title = notification.title.toLowerCase();
    final body = notification.body.toLowerCase();

    IconData iconData = AppIcons.notification;
    Color typeColor = AppColors.primary;

    if (title.contains('assignment') ||
        body.contains('assignment') ||
        title.contains('واجب')) {
      iconData = Icons.assignment_rounded;
      typeColor = Colors.orange;
    } else if (title.contains('update') ||
        body.contains('update') ||
        title.contains('تحديث')) {
      iconData = Icons.system_update_alt_rounded;
      typeColor = Colors.blue;
    } else if (title.contains('congrats') ||
        body.contains('congrats') ||
        title.contains('مبروك')) {
      iconData = Icons.emoji_events_rounded;
      typeColor = Colors.green;
    }

    return Semantics(
      button: true,
      label:
          '${notification.title}, ${notification.isRead ? l10n.completedFilter : l10n.unreadFilter}',
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        child: InkWell(
          onTap: () => _showDetails(context, ref),
          borderRadius: AppRadius.mdBorder,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: notification.isRead ? ds.background : ds.surface,
              borderRadius: AppRadius.mdBorder,
              border: Border.all(
                color: notification.isRead
                    ? ds.border
                    : typeColor.withValues(alpha: 0.3),
              ),
              boxShadow: notification.isRead
                  ? null
                  : [
                      BoxShadow(
                        color: typeColor.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: notification.isRead
                            ? ds.surface2.withValues(alpha: 0.5)
                            : typeColor.withValues(alpha: 0.1),
                        borderRadius: AppRadius.smBorder,
                      ),
                      child: Icon(
                        iconData,
                        color: notification.isRead ? ds.textMuted : typeColor,
                        size: 24,
                      ),
                    ),
                    if (!notification.isRead)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                            border: Border.all(color: ds.surface, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: notification.isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                color: ds.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            timeago.format(
                              notification.createdAt,
                              locale: languageCode,
                            ),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: ds.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: ds.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
