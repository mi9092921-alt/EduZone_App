import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../shared/utils/error_handler.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../../auth/domain/entities/auth_state.dart';
import '../../application/providers/notifications_provider.dart';
import '../../domain/entities/app_notification.dart';
import '../widgets/notification_tile.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final ds = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return AppPageScaffold(
      title: l10n.notificationsTitle,
      centerTitle: true,
      leading: const BackButton(),
      backgroundColor: ds.background,
      actions: [
        TextButton(
          onPressed: () {
            // Source the current user id from the app's own auth state
            // (Section 6/8: no direct backend-singleton access from a
            // widget's business logic) rather than reaching into
            // `SupabaseService.client` directly — that made this action
            // impossible to exercise from a widget/integration test
            // without a real, initialized Supabase client.
            final authState = ref.read(authProvider);
            final userId = authState is AuthAuthenticated
                ? authState.user.id
                : null;
            if (userId != null) {
              ref.read(markAsReadProvider).call(null, userId);
            }
          },
          child: Text(
            l10n.markAllRead,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
      slivers: [
        SliverToBoxAdapter(child: _buildFilterBar(context)),
        ..._buildContentSlivers(context, ref, notificationsAsync),
      ],
    );
  }

  List<Widget> _buildContentSlivers(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<AppNotification>> notificationsAsync,
  ) {
    return notificationsAsync.when(
      data: (notifications) {
        final activeFilter = ref.watch(notificationFilterProvider);
        final filteredList = activeFilter == 'all'
            ? notifications
            : notifications.where((n) => !n.isRead).toList();

        if (filteredList.isEmpty) {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(context, activeFilter),
            ),
          ];
        }

        return [
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            sliver: SliverList(
              // P8.8 fix: stable keys so list diffing matches tiles by
              // notification identity, not slot position, when the list
              // is re-filtered (all/unread) or a new notification arrives
              // — mirrors the key: ValueKey(...) pattern already used on
              // course-card items (e.g. DiscoverCourseCard).
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index.isOdd) {
                    return const SizedBox(height: AppSpacing.sm);
                  }

                  final notification = filteredList[index ~/ 2];
                  return NotificationTile(
                    key: ValueKey(notification.id),
                    notification: notification,
                  );
                },
                childCount: filteredList.isEmpty
                    ? 0
                    : filteredList.length * 2 - 1,
              ),
            ),
          ),
        ];
      },
      loading: () => [
        SliverToBoxAdapter(child: _buildLoadingSkeleton(context)),
      ],
      error: (e, s) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                ErrorHandler.getMessage(context, e),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final activeFilter = ref.watch(notificationFilterProvider);
        final l10n = AppLocalizations.of(context)!;
        final scheme = Theme.of(context).colorScheme;

        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilterChip(
                label: Text(l10n.allFilter),
                selected: activeFilter == 'all',
                onSelected: (_) => ref
                    .read(notificationFilterProvider.notifier)
                    .setFilter('all'),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                showCheckmark: false,
                selectedColor: scheme.primaryContainer,
                side: BorderSide(color: scheme.outlineVariant),
                labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: activeFilter == 'all'
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
              FilterChip(
                label: Text(l10n.unreadFilter),
                selected: activeFilter == 'unread',
                onSelected: (_) => ref
                    .read(notificationFilterProvider.notifier)
                    .setFilter('unread'),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                showCheckmark: false,
                selectedColor: scheme.primaryContainer,
                side: BorderSide(color: scheme.outlineVariant),
                labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: activeFilter == 'unread'
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, String filter) {
    final ds = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl2), // check-ignore -- already a token; false positive (regex matches the digit in "xl2")
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: ds.surface2.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                filter == 'unread'
                    ? Icons.mark_email_read_outlined
                    : Icons.notifications_none_rounded,
                size: 64,
                color: ds.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              filter == 'unread'
                  ? l10n.noUnreadNotifications
                  : l10n.noNotifications,
              style: AppTextStyles.h3.copyWith(color: ds.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.notificationsEmptyDesc,
              style: AppTextStyles.bodyMedium.copyWith(color: ds.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    return AppSkeleton(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 8,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          return NotificationTile(notification: AppNotification.skeleton());
        },
      ),
    );
  }
}
