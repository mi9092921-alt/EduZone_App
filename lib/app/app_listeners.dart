import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/courses/application/providers/course_refresh_listener.dart';
import '../../features/downloads/application/listeners/offline_account_purge_listener.dart';
import '../../features/home/application/providers/home_refresh_listener.dart';

part 'app_listeners.g.dart';

/// Composition root for event-bus listeners that must be subscribed for the
/// whole app lifetime, regardless of which screen is visible.
///
/// Eagerly watched by [EduZoneApp.build] (same bootstrap pattern as
/// `eventDispatcherProvider`). Each listener owns its subscription lifecycle
/// via `ref.onDispose` and may only touch its own feature's internals —
/// cross-feature communication flows through the [EventBus], never through
/// direct feature-to-feature imports.
///
/// This is intentionally app-lifetime state: the composition root owns the
/// subscriptions, while each listener is invalidated at logout and cleans up
/// its subscription through `ref.onDispose`.
@Riverpod(keepAlive: true) // check-ignore: app-lifetime composition-root listener
void appListeners(Ref ref) {
  ref.watch(offlineAccountPurgeListenerProvider);
  ref.watch(courseRefreshListenerProvider);
  ref.watch(homeRefreshListenerProvider);
}
