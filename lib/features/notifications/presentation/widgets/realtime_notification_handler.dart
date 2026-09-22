import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/utils/app_snackbar.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../application/providers/notifications_provider.dart';

/// Coalescing throttle with a leading + trailing edge.
///
/// The `user_notifications` realtime stream emits one event per affected
/// ROW, not per change: a single `markAllAsRead` update surfaces as N
/// events, and a burst of incoming notifications as one event each.
/// Refreshing the notifications list on every event cost one full refetch
/// (2 queries) per row — marking N notifications read produced N refetches
/// within the same instant.
///
/// With this throttle, the first event triggers [onRefresh] immediately
/// (new-notification toasts stay instant) and opens a window of
/// [minInterval]; events arriving inside the window collapse into a single
/// trailing refresh when it closes. Data freshness is unchanged; the
/// request storm is not.
///
/// The window is defined purely by the timer's lifetime — never by
/// DateTime.now() comparisons — so throttling behaves identically in real
/// time and under the test binding's fake clock.
class RealtimeRefreshThrottle {
  final Duration minInterval;
  final void Function() onRefresh;

  Timer? _windowTimer;
  bool _hasPendingEvent = false;
  bool _disposed = false;

  RealtimeRefreshThrottle({required this.minInterval, required this.onRefresh});

  /// Registers one realtime event and refreshes according to the throttle
  /// window. No-op after [dispose].
  void notify() {
    if (_disposed) return;
    if (_windowTimer != null) {
      _hasPendingEvent = true;
      return;
    }

    onRefresh();
    _hasPendingEvent = false;
    _windowTimer = Timer(minInterval, () {
      _windowTimer = null;
      if (_disposed || !_hasPendingEvent) return;
      _hasPendingEvent = false;
      onRefresh();
    });
  }

  void dispose() {
    _disposed = true;
    _windowTimer?.cancel();
    _windowTimer = null;
  }
}

/// A global widget that listens to the notification stream and shows
/// in-app alerts (toasts/snackbars) when new notifications arrive.
class RealtimeNotificationHandler extends ConsumerStatefulWidget {
  final Widget child;

  const RealtimeNotificationHandler({super.key, required this.child});

  @override
  ConsumerState<RealtimeNotificationHandler> createState() =>
      _RealtimeNotificationHandlerState();
}

class _RealtimeNotificationHandlerState
    extends ConsumerState<RealtimeNotificationHandler> {
  final Set<String> _seenNotificationIds = {};
  bool _isFirstLoad = true;

  /// The account the seen-set/first-load state above belongs to. Both are
  /// per-account state: without resetting on an account change, the next
  /// account's pre-existing unread notifications would all be "unseen" and
  /// trigger one toast each at login (this widget outlives sessions — it is
  /// mounted at the app root above the router), and the set would grow
  /// unboundedly across accounts.
  String? _ownerUserId;

  static const Duration _minRefreshInterval = Duration(milliseconds: 600);

  late final RealtimeRefreshThrottle _refreshThrottle = RealtimeRefreshThrottle(
    minInterval: _minRefreshInterval,
    onRefresh: () {
      if (mounted) ref.invalidate(notificationsProvider);
    },
  );

  @override
  void dispose() {
    _refreshThrottle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild the subscription when the authenticated user changes. Without
    // this dependency, the handler created during splash would keep the
    // empty pre-auth stream after login.
    ref.watch(authProvider);

    // Reset the per-account toast state when the account changes (including
    // logout → null): the next account's first load re-seeds the seen-set
    // from ITS existing notifications instead of toasting every one of them.
    final ownerUserId = ref.watch(currentUserIdProvider);
    if (_ownerUserId != ownerUserId) {
      _ownerUserId = ownerUserId;
      _seenNotificationIds.clear();
      _isFirstLoad = true;
    }

    ref.listen(notificationsChangesProvider, (previous, next) {
      next.whenData((_) => _refreshThrottle.notify());
    });

    // Listen to the notifications provider
    ref.listen(notificationsProvider, (previous, next) {
      next.whenData((notifications) {
        if (_isFirstLoad) {
          // On first load, mark all current notifications as "seen"
          // to avoid alerting the user for old stuff during app startup.
          for (final n in notifications) {
            _seenNotificationIds.add(n.id);
          }
          _isFirstLoad = false;
          return;
        }

        // Check for new unread notifications that we haven't seen yet
        for (final notification in notifications) {
          if (!notification.isRead &&
              !_seenNotificationIds.contains(notification.id)) {
            _seenNotificationIds.add(notification.id);

            // Show the in-app alert
            FeedbackService.show(context, message: notification.title);
          }
        }
      });
    });

    return widget.child;
  }
}
