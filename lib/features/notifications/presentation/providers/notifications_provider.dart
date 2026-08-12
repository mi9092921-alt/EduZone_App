import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/supabase_client.dart';
import '../../data/datasources/notifications_remote_ds.dart';
import '../../data/repositories/notifications_repo_impl.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../../domain/usecases/get_notifications.dart';
import '../../domain/usecases/mark_as_read.dart';

part 'notifications_provider.g.dart';

@riverpod
NotificationsRemoteDataSource notificationsRemoteDataSource(Ref ref) {
  return NotificationsRemoteDataSourceImpl();
}

@riverpod
NotificationsRepository notificationsRepository(Ref ref) {
  return NotificationsRepositoryImpl(ref.watch(notificationsRemoteDataSourceProvider));
}

@riverpod
GetNotifications getNotifications(Ref ref) {
  return GetNotifications(ref.watch(notificationsRepositoryProvider));
}

@riverpod
MarkAsRead markAsRead(Ref ref) {
  return MarkAsRead(ref.watch(notificationsRepositoryProvider));
}

@riverpod
Future<List<AppNotification>> notifications(Ref ref) async {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) {
    return [];
  }

  final getNotifications = ref.watch(getNotificationsProvider);
  final result = await getNotifications(userId);
  
  return result.fold(
    (failure) => throw failure,
    (notifications) => notifications,
  );
}

@riverpod
class NotificationFilter extends _$NotificationFilter {
  @override
  String build() => 'all';

  void setFilter(String filter) {
    state = filter;
  }
}

@riverpod
int unreadCount(Ref ref) {
  final notifications = ref.watch(notificationsProvider).value;
  if (notifications == null) return 0;

  return notifications.where((n) => !n.isRead).length;
}

// ─── Session cleanup ─────────────────────────────────────────────────────────

/// Invalidates every user-scoped provider owned by the `notifications`
/// feature. Called by [Auth.logout]. When you add a new user-scoped
/// provider to this file, add it here too.
void invalidateNotificationsProviders(Ref ref) {
  ref.invalidate(notificationsProvider);
  ref.invalidate(notificationFilterProvider);
  ref.invalidate(unreadCountProvider);
  ref.invalidate(notificationsRemoteDataSourceProvider);
}