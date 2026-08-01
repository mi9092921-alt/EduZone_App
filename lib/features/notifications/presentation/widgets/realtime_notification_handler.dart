import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/utils/app_snackbar.dart';
import '../providers/notifications_provider.dart';

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

  @override
  Widget build(BuildContext context) {
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
            FeedbackService.show(
              context,
              message: notification.title,
            );
          }
        }
      });
    });

    return widget.child;
  }
}
