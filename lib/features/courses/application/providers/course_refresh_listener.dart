import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/logging/domain/app_event.dart';
import '../../../../core/logging/logging_providers.dart';
import 'courses_provider.dart';

part 'course_refresh_listener.g.dart';

/// Listens for [LessonProgressChangedEvent] (emitted by video_player when a
/// lesson's completion state changes) and invalidates this feature's own
/// progress providers, so course progress never shows stale data after
/// leaving the player.
///
/// Lives in the courses feature (not video_player) so it can invalidate its
/// own providers without video_player importing courses internals.
///
/// Eagerly subscribed by `lib/app/app_listeners.dart` at app startup.
@Riverpod(keepAlive: true)
StreamSubscription<void> courseRefreshListener(Ref ref) {
  final sub = ref.watch(eventBusProvider).stream.listen((event) {
    if (event is! LessonProgressChangedEvent) return;
    ref.invalidate(courseProgressProvider(event.courseId));
    ref.invalidate(myCoursesProvider);
  });
  ref.onDispose(sub.cancel);
  return sub;
}

/// Invalidates the app-wide progress listener at a session boundary so its
/// subscription is rebuilt with the next account's provider graph.
void invalidateCourseRefreshProviders(Ref ref) {
  ref.invalidate(courseRefreshListenerProvider);
}
