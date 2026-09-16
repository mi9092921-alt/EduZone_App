import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/logging/domain/app_event.dart';
import '../../../../core/logging/logging_providers.dart';
import 'home_provider.dart';

part 'home_refresh_listener.g.dart';

/// Listens for [LessonProgressChangedEvent] (emitted by video_player when a
/// lesson's completion state changes) and invalidates this feature's own
/// resume/recent providers, so "Continue Learning" sections never show
/// stale progress after leaving the player.
///
/// Lives in the home feature (not video_player) so it can invalidate its
/// own providers without video_player importing home internals.
///
/// Eagerly subscribed by `lib/app/app_listeners.dart` at app startup.
@Riverpod(keepAlive: true)
StreamSubscription<void> homeRefreshListener(Ref ref) {
  final sub = ref.watch(eventBusProvider).stream.listen((event) {
    if (event is! LessonProgressChangedEvent) return;
    ref.invalidate(resumeLessonsProvider);
    ref.invalidate(recentCoursesProvider);
  });
  ref.onDispose(sub.cancel);
  return sub;
}
