import 'dart:async';

import 'package:app/core/feature_flags/feature_flags_provider.dart';
import 'package:app/core/logging/logging_providers.dart';
import 'package:app/features/courses/application/providers/course_refresh_listener.dart';
import 'package:app/features/courses/application/providers/courses_provider.dart';
import 'package:app/features/downloads/application/listeners/offline_account_purge_listener.dart';
import 'package:app/features/downloads/application/providers/downloads_provider.dart';
import 'package:app/features/home/application/providers/home_provider.dart';
import 'package:app/features/home/application/providers/home_refresh_listener.dart';
import 'package:app/features/notifications/application/providers/notifications_provider.dart';
import 'package:app/features/profile/application/providers/profile_provider.dart';
import 'package:app/features/todo/application/providers/todo_provider.dart';
import 'package:app/features/video_player/application/providers/player4_provider.dart';
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
  // Phase 11: drop every cached signed-URL entry (the family key already
  // partitions them per account, so the next account could never HIT a
  // stale entry — this is memory hygiene for the keepAlive'd instances,
  // same pattern as invalidateVideoProgressProviders above).
  ref.invalidate(player4VideoInfoProvider);
  // Phase 11: the Player4 lesson side-channel (set by Player4Wrapper before
  // every video-info read so the Edge Function can authorize the specific
  // lesson) is autoDispose and normally dies with its last listener at the
  // router redirect — but a logout that lands anywhere except a lesson
  // route must not leave a stale lesson id behind for the next account's
  // first video-info call to inherit.
  ref.invalidate(player4PendingLessonIdProvider);
  // Feature-flag snapshots are user-scoped too: the evaluator targets by
  // JWT (rollout/user/tenant overrides), so the keep-alive snapshot of the
  // outgoing account must not be served to the next one. Invalidation
  // rebuilds from safe defaults (no session → no cache to load); the next
  // authenticated session re-fetches via the auth flow's refresh hook.
  ref.invalidate(featureFlagsProvider);
  // Pending telemetry queued by the outgoing account must not be flushed
  // after the account boundary: LogQueue entries carry the enqueueing
  // account's userId, and the sync datasource reads the *ambient* Supabase
  // session at flush time — under the next account they would be retried
  // (and rejected server-side) with the wrong attribution. The queue is
  // in-memory only and its own contract documents clear() as the logout
  // cleanup step (log_queue.dart), so dropping it here is the intended
  // behavior, not silent data loss.
  ref.read(logQueueProvider).clear();
  invalidateCourseRefreshProviders(ref);
  invalidateOfflineAccountPurgeProviders(ref);
  invalidateHomeRefreshProviders(ref);
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
///
/// [userId] scopes the engine's disk outbox: progress queued by a previous
/// session of this SAME account (app kill) is restored here; any other
/// account's snapshot stays on its own key, unread. Callers must pass the
/// id of the account that was just authenticated — never the ambient
/// session read, so the scope cannot drift from the state machine's verdict.
void openUserProgressSession(Ref ref, String userId) {
  ref.read(lessonProgressSyncEngineProvider).openSession(userId);
}
