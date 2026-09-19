import 'package:flutter_riverpod/flutter_riverpod.dart';
// ProviderListenable is exported from misc.dart in the pinned Riverpod 3.x.
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../../../../shared/models/app_notification.dart';
import '../../../../../shared/providers/home_notifications_gateway.dart';
import '../providers/notifications_provider.dart';

/// Notifications-feature implementation of the home dashboard gateway
/// contract (see [HomeNotificationsGateway]). Bridges the feature's own
/// providers onto the shared seam without home importing this feature.
class HomeNotificationsGatewayImpl implements HomeNotificationsGateway {
  HomeNotificationsGatewayImpl(this._ref);

  final Ref _ref;

  @override
  ProviderListenable<AsyncValue<List<AppNotification>>> get notifications =>
      notificationsProvider;

  @override
  ProviderListenable<int> get unreadCount => unreadCountProvider;

  @override
  Future<bool> markAsRead({
    required String notificationId,
    required String userId,
  }) async {
    final result = await _ref.read(markAsReadProvider).call(
          notificationId,
          userId,
        );
    return result.isRight();
  }

  @override
  void refresh() {
    _ref.invalidate(notificationsProvider);
  }
}
