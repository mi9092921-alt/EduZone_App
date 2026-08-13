import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
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
  return VideoPlayerRemoteDataSource();
}

@riverpod
VideoPlayerRepository videoPlayerRepository(Ref ref) {
  return VideoPlayerRepositoryImpl(ref.watch(videoPlayerRemoteDataSourceProvider));
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
final lessonProgressSyncEngineProvider = Provider<LessonProgressSyncEngine>((ref) { // check-ignore
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

  late final VideoPlayerRepository _repo;
  late final LessonProgressSyncEngine _syncEngine;

  @override
  VideoState build(String courseId, String lessonId) {
    // Prevent auto-dispose from tearing this down between progress ticks,
    // since callers use ref.read(...) rather than ref.watch(...).
    ref.keepAlive();

    // Resolve dependencies once, while ref is still valid. These are plain
    // object references from here on — safe to use even after this
    // provider itself has been disposed.
    _repo = ref.read(videoPlayerRepositoryProvider);
    _syncEngine = ref.read(lessonProgressSyncEngineProvider);

    ref.onDispose(() {
      _syncTimer?.cancel();
      // Final sync on dispose if progress was made. Safe: _syncToDb no
      // longer touches ref or state.
      if (_lastWatchTimeSec > 0) {
        _queueSync(courseId, lessonId, flushNow: true);
      }
    });

    return VideoState(
      progressPct: 0.0,
      watchTimeSec: 0,
      isCompleted: false,
    );
  }

  void updateProgress(double pct, int watchTimeSec, String courseId, String lessonId) {
    final currentPct = math.min(pct, 100.0);
    final wasCompleted = _markedComplete;

    // Auto-complete at 90%
    if (currentPct >= 90.0 && !_markedComplete) {
      _markedComplete = true;
    }

    _lastWatchTimeSec = watchTimeSec;
    _lastProgressPct = currentPct;

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
      state = state.copyWith(isCompleted: true);
      _syncTimer?.cancel();
      _queueSync(courseId, lessonId, flushNow: true);
      _logCompletion(courseId, lessonId);
    }
  }

  void _scheduleDebouncedSync(String courseId, String lessonId) {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 10), () {
      _queueSync(courseId, lessonId, flushNow: true);
    });
  }

  /// Does NOT use `ref` or `state` — safe to call from onDispose or after disposal.
  void _queueSync(
    String courseId,
    String lessonId, {
    bool flushNow = false,
  }) {
    _syncEngine.enqueue(
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

  /// Does NOT use `ref` or `state` — safe to call from onDispose or after disposal.
  Future<void> _logCompletion(String courseId, String lessonId) async {
    try {
      await _repo.logActivity(
        eventType: 'lesson_completed',
        metadata: {
          'course_id': courseId,
          'lesson_id': lessonId,
        },
      );
    } catch (_) {
      // Best effort
    }
  }
}
