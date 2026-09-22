import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/logging/domain/app_event.dart';
import '../../../../core/logging/logging_providers.dart';
import 'home_provider.dart';

part 'home_refresh_listener.g.dart';

/// Listens for [LessonProgressChangedEvent] (emitted by video_player when a
/// lesson's completion state changes) and [TodoListChangedEvent] (emitted by
/// the todo notifier's success branches) and invalidates this feature's own
/// resume/recent providers, so "Continue Learning" and "Daily tasks"
/// sections never show stale data after leaving the player or the todo
/// screen.
///
/// Lives in the home feature (not video_player) so it can invalidate its
/// own providers without video_player importing home internals.
///
/// Eagerly subscribed by `lib/app/app_listeners.dart` at app startup.
@Riverpod(keepAlive: true)
StreamSubscription<void> homeRefreshListener(Ref ref) {
  final sub = ref.watch(eventBusProvider).stream.listen((event) {
    if (event is LessonProgressChangedEvent) {
      ref.invalidate(resumeLessonsProvider);
      ref.invalidate(recentCoursesProvider);
    }
    // Phase 10: todo mutations previously left the home "Daily tasks"
    // preview stale (the provider only refreshed on pull-to-refresh or
    // logout, and MainShell keeps the home branch cached while the student
    // is on the todo tab).
    if (event is TodoListChangedEvent) {
      ref.invalidate(recentTodosProvider);
    }
  });
  ref.onDispose(sub.cancel);
  return sub;
}

/// Invalidates the app-wide home listener at a session boundary so its
/// subscription is rebuilt with the next account's provider graph.
void invalidateHomeRefreshProviders(Ref ref) {
  ref.invalidate(homeRefreshListenerProvider);
}
