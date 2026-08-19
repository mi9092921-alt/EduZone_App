import 'dart:async';

import 'package:app/features/courses/application/providers/courses_provider.dart';
import 'package:app/features/downloads/application/providers/downloads_provider.dart';
import 'package:app/features/home/application/providers/home_provider.dart';
import 'package:app/features/notifications/application/providers/notifications_provider.dart';
import 'package:app/features/profile/application/providers/profile_provider.dart';
import 'package:app/features/todo/application/providers/todo_provider.dart';
import 'package:app/features/video_player/application/providers/video_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

/// Composition-root aggregator for "invalidate everything user-scoped on
/// logout" (ARCH-001).
///
/// Previously `auth_provider.dart` imported all five of these feature
/// provider files directly, which the architecture guard
/// (tool/check_architecture.py) flags as cross-feature coupling -- the
/// `auth` feature reaching into `courses`/`home`/`notifications`/`profile`/
/// `todo` internals directly.
///
/// Moving the aggregation here instead is the composition-root pattern:
/// files under lib/app/** are the one place allowed to know about every
/// feature at once (see check_architecture.py's EXEMPT_PATH_FRAGMENTS).
/// `auth_provider.dart` now depends only on this single file instead of on
/// five separate feature internals.
///
/// `downloads` was added (STATE-001): its `keepAlive` in-memory download
/// list/storage-total providers were never wired into this aggregator, so
/// they survived logout unlike every other feature's user-scoped state.
/// See the doc comment on `invalidateDownloadsProviders` in
/// downloads_provider.dart for the full account-isolation rationale.
///
/// `video_player` was added (STATE-002, same class of bug as STATE-001):
/// `VideoProgress`'s per-(courseId, lessonId) `keepAlive()` state was never
/// wired into this aggregator either. See the doc comment on
/// `invalidateVideoProgressProviders` in video_provider.dart.
void invalidateAllUserScopedProviders(Ref ref) {
  invalidateProfileProviders(ref);
  invalidateCoursesProviders(ref);
  invalidateTodoProviders(ref);
  invalidateHomeProviders(ref);
  invalidateNotificationsProviders(ref);
  invalidateDownloadsProviders(ref);
  invalidateVideoProgressProviders(ref);
}

/// Closes the shared lesson-progress queue at a logout boundary. Manual
/// logout calls this before clearing Supabase's local session so pending
/// progress still has the correct user's token available for one final flush.
Future<void> flushAndCloseUserProgressSession(Ref ref) {
  return ref
      .read(lessonProgressSyncEngineProvider)
      .closeSession(flushPending: true);
}

/// Discards the shared lesson-progress queue immediately after a passive
/// revocation or rejected session. No retry may run under a future account.
void closeUserProgressSession(Ref ref) {
  unawaited(ref.read(lessonProgressSyncEngineProvider).closeSession());
}

/// Reopens the shared queue after a new authenticated session is established.
void openUserProgressSession(Ref ref) {
  ref.read(lessonProgressSyncEngineProvider).openSession();
}
