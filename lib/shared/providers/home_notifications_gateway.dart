import 'package:flutter_riverpod/flutter_riverpod.dart';
// ProviderListenable is exported from misc.dart in the pinned Riverpod 3.x.
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../models/app_notification.dart';

/// Cross-feature contract through which the `home` feature reads the
/// notifications state for its dashboard preview WITHOUT importing the
/// `notifications` feature (AGENTS import rules: features must not import
/// other features; cross-feature data routes through shared).
///
/// The concrete implementation lives in
/// `features/notifications/application/services/home_notifications_gateway_impl.dart`
/// and is injected at the composition root (`main.dart` ProviderScope
/// overrides). A null provider value (bare test containers) means "no
/// notifications surface on the dashboard" — consumers must degrade
/// gracefully.
abstract interface class HomeNotificationsGateway {
  /// Reactive latest-notifications state for the signed-in account.
  ProviderListenable<AsyncValue<List<AppNotification>>> get notifications;

  /// Reactive unread count derived from the notifications list.
  ProviderListenable<int> get unreadCount;

  /// Marks one notification as read. Returns true on success.
  Future<bool> markAsRead({
    required String notificationId,
    required String userId,
  });

  /// Re-fetches the notifications list (after a successful mark-as-read).
  void refresh();
}

/// Composition-root injection point. Overridden in `main.dart` with the
/// notifications-feature implementation; stays null otherwise.
// Manual (non-codegen) provider — deliberate: this is composition-root
// plumbing for a cross-feature seam, mirroring the documented manual
// providers in shared/providers (download_network_policy_provider).
// check-ignore: provider defined outside application/providers by design.
// check-ignore: app-lifetime seam — the gateway holds the injected feature
// implementation for the whole session; an auto-dispose variant would tear
// down the shared contract whenever the last watcher unmounts.
final homeNotificationsGatewayProvider =
    Provider<HomeNotificationsGateway?>((ref) => null); // check-ignore
