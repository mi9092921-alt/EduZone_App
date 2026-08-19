import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/application/providers/auth_di_providers.dart';
import '../../data/datasources/video_player_remote_ds.dart';
import '../../data/repositories/video_player_repo_impl.dart';
import '../../domain/entities/lesson_progress_sync_item.dart';
import '../../domain/repositories/video_player_repository.dart';
import '../../domain/usecases/sync_lesson_progress.dart';
import '../services/lesson_progress_sync_engine.dart';

part 'video_provider.g.dart';

// ─── DI Providers ───────────────────────────────────────────────

@riverpod
VideoPlayerRemoteDataSource videoPlayerRemoteDataSource(Ref ref) {
  return VideoPlayerRemoteDataSource(
    ref.watch(supabaseClientProvider),
  );
}

@riverpod
VideoPlayerRepository videoPlayerRepository(Ref ref) {
  return VideoPlayerRepositoryImpl(
    ref.watch(videoPlayerRemoteDataSourceProvider),
  );
}

@riverpod
SyncLessonProgress syncLessonProgress(Ref ref) {
  return SyncLessonProgress(ref.watch(videoPlayerRepositoryProvider));
}

/// Intentionally NOT AutoDispose / NOT `@riverpod`-generated.
///
/// This engine batches and debounces lesson-progress syncs across every
/// [VideoProgress] instance (one per courseId/lessonId pair, each of which
/// keeps itself alive via `ref.keepAlive()`). It must stay a single
/// app-lifetime instance so that progress queued while watching one lesson
/// is still flushed correctly if the user immediately opens another lesson
/// before the first sync completes. Reviewed 2026-08-13 as part of the
/// memory-hygiene audit; see tool/check_memory_hygiene.py.
final lessonProgressSyncEngineProvider = Provider<LessonProgressSyncEngine>(( // check-ignore
  ref,
) {
  // check-ignore
  final engine = LessonProgressSyncEngine(
    syncLessonProgress: ref.watch(syncLessonProgressProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

// ─── Video Progress State ───────────────────────────────────────

class VideoState {
  final double progressPct;
  final int watchTimeSec;
  final bool isCompleted;

  VideoState({
    required this.progressPct,
    required this.watchTimeSec,
    required this.isCompleted,
  });

  VideoState copyWith({
    double? progressPct,
    int? watchTimeSec,
    bool? isCompleted,
  }) {
    return VideoState(
      progressPct: progressPct ?? this.progressPct,
      watchTimeSec: watchTimeSec ?? this.watchTimeSec,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// Manages video playback progress state and debounced DB sync.
///
/// IMPORTANT: this notifier calls `ref.keepAlive()` in [build] so it is not
/// disposed the moment its last listener drops off (e.g. when the player
/// widget calls `ref.read(...)` instead of `ref.watch(...)`). Without this,
/// the provider gets auto-disposed almost immediately after creation, and
/// any subsequent use of `ref` inside `onDispose` (or anything scheduled
/// after disposal, like the debounce Timer) throws:
///   "Cannot use the Ref of videoProgressProvider(...) after it has been disposed."
///
/// All external dependencies (`SyncLessonProgress`, `VideoPlayerRepository`)
/// are resolved once during [build] and cached as fields. `_syncToDb` and
/// `_logCompletion` must NEVER call `ref.read`/`ref.watch` themselves,
/// since they can run from `onDispose` or from a Timer that fires after
/// disposal — at which point `ref` is no longer usable.
@riverpod
class VideoProgress extends _$VideoProgress {
  Timer? _syncTimer;
  bool _markedComplete = false;
  int _lastWatchTimeSec = 0;
  double _lastProgressPct = 0.0;

  VideoPlayerRepository? _repo;
  LessonProgressSyncEngine? _syncEngine;
  int _buildGeneration = 0;
  bool _hasPendingProgress = false;

  @override
  VideoState build(String courseId, String lessonId) {
    final buildGeneration = ++_buildGeneration;
    // Prevent auto-dispose from tearing this down between progress ticks,
    // since callers use ref.read(...) rather than ref.watch(...).
    ref.keepAlive();

    // A kept-alive provider is rebuilt in place when invalidated. Flush the
    // previous account's unsent progress and reset all in-memory state first.
    // `_hasPendingProgress` makes this idempotent with the onDispose callback:
    // Riverpod may run that callback either before or after the rebuild.
    _flushPendingProgress(courseId, lessonId);
    _syncTimer?.cancel();
    _syncTimer = null;
    _markedComplete = false;
    _lastWatchTimeSec = 0;
    _lastProgressPct = 0.0;
    _hasPendingProgress = false;

    // Resolve dependencies once, while ref is still valid. These are plain
    // object references from here on — safe to use even after this
    // provider itself has been disposed.
    _repo = ref.read(videoPlayerRepositoryProvider);
    _syncEngine = ref.read(lessonProgressSyncEngineProvider);

    ref.onDispose(() {
      // If this callback belongs to a previous build and Riverpod invokes it
      // after the replacement build started, the replacement build already
      // flushed the old snapshot. Do not flush the new account's state here.
      if (buildGeneration != _buildGeneration) return;

      _syncTimer?.cancel();
      _flushPendingProgress(courseId, lessonId);
      _lastWatchTimeSec = 0;
      _lastProgressPct = 0.0;
      _markedComplete = false;
      _repo = null;
      _syncEngine = null;
    });

    return VideoState(progressPct: 0.0, watchTimeSec: 0, isCompleted: false);
  }

  void updateProgress(
    double pct,
    int watchTimeSec,
    String courseId,
    String lessonId,
  ) {
    final currentPct = math.min(pct, 100.0);
    final wasCompleted = _markedComplete;

    // Auto-complete at 90%
    if (currentPct >= 90.0 && !_markedComplete) {
      _markedComplete = true;
    }

    _lastWatchTimeSec = watchTimeSec;
    _lastProgressPct = currentPct;
    _hasPendingProgress = true;

    state = state.copyWith(
      progressPct: currentPct,
      watchTimeSec: watchTimeSec,
      isCompleted: _markedComplete,
    );

    if (_markedComplete && !wasCompleted) {
      // Force immediate sync on completion
      _syncTimer?.cancel();
      _queueSync(courseId, lessonId, flushNow: true);
      _logCompletion(courseId, lessonId);
    } else {
      _scheduleDebouncedSync(courseId, lessonId);
    }
  }

  void markAsCompleted(String courseId, String lessonId) {
    if (!_markedComplete) {
      _markedComplete = true;
      _lastProgressPct = 100.0;
      _hasPendingProgress = true;
      state = state.copyWith(isCompleted: true);
      _syncTimer?.cancel();
      _queueSync(courseId, lessonId, flushNow: true);
      _logCompletion(courseId, lessonId);
    }
  }

  void _scheduleDebouncedSync(String courseId, String lessonId) {
    _syncTimer?.cancel();
    final buildGeneration = _buildGeneration;
    _syncTimer = Timer(const Duration(seconds: 10), () {
      if (buildGeneration != _buildGeneration) return;
      _queueSync(courseId, lessonId, flushNow: true);
    });
  }

  /// Does NOT use `ref` or `state` — safe to call from onDispose or after disposal.
  void _queueSync(String courseId, String lessonId, {bool flushNow = false}) {
    if (_syncEngine == null || !_hasPendingProgress) return;
    _hasPendingProgress = false;
    _syncEngine?.enqueue(
      LessonProgressSyncItem(
        courseId: courseId,
        lessonId: lessonId,
        completed: _markedComplete,
        progressPct: _lastProgressPct,
        watchTimeSec: _lastWatchTimeSec,
      ),
      flushNow: flushNow,
    );
  }

  /// Takes a snapshot before a provider rebuild/dispose can clear its fields.
  /// Does not touch Riverpod's [ref] or [state].
  void _flushPendingProgress(String courseId, String lessonId) {
    if (!_hasPendingProgress) return;
    _queueSync(courseId, lessonId, flushNow: true);
  }

  /// Does NOT use `ref` or `state` — safe to call from onDispose or after disposal.
  Future<void> _logCompletion(String courseId, String lessonId) async {
    try {
      await _repo?.logActivity(
        eventType: 'lesson_completed',
        metadata: {'course_id': courseId, 'lesson_id': lessonId},
      );
    } catch (_) {
      // Best effort
    }
  }
}

// ─── Session cleanup ─────────────────────────────────────────────────────────

/// Invalidates every user-scoped provider owned by the `video_player`
/// feature. Called by [Auth.logout]. When you add a new user-scoped
/// provider to this file, add it here too.
///
/// [videoProgressProvider] is a family, one instance per (courseId,
/// lessonId), and — like [downloadsProvider]/[bookmarkedCoursesProvider]
/// before this feature was audited — each instance keeps itself alive via
/// `ref.keepAlive()` (see the class doc comment on [VideoProgress]), so it
/// is never torn down just because the player widget navigates away. Left
/// unaddressed, if a second account signs in on the same device without a
/// full app restart and opens a lesson the first account had already been
/// watching, the progress bar/"resume from X%"/completed badge would show
/// the first account's in-memory watch progress rather than the second
/// account's — the same account-isolation violation already fixed for
/// downloads and course bookmarks/progress (STATE-001).
///
/// Invalidating the family here is also the *correct* way to end the
/// session, not just a privacy fix: [VideoProgress]'s own `ref.onDispose`
/// already flushes any pending unsynced progress via [_queueSync] before
/// tearing down, so calling this from logout ensures the last few seconds
/// of watch time are persisted rather than silently dropped.
///
/// [player4VideoInfoProvider] (Player4VideoInfo, in player4_provider.dart)
/// is deliberately NOT invalidated here: it caches a signed streaming URL
/// keyed by videoId, not by account, and already self-invalidates on its
/// own `cacheExpiresAt` timer regardless of which account is signed in, so
/// leaving it alive across a logout does not leak account-specific data.
void invalidateVideoProgressProviders(Ref ref) {
  ref.invalidate(videoProgressProvider);
}
