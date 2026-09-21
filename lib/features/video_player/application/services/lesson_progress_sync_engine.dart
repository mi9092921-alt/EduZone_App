import 'dart:async';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/lesson_progress_sync_item.dart';
import '../../domain/usecases/sync_lesson_progress.dart';

class LessonProgressSyncEngine {
  final SyncLessonProgress _syncLessonProgress;
  final Duration flushInterval;
  final int maxBatchSize;

  /// Ceiling for the exponential retry delay after consecutive failed
  /// flushes (flushInterval * 2^failures, capped here).
  final Duration maxRetryDelay;

  /// After this many consecutive failed flushes the periodic retry stops
  /// scheduling itself — a deterministic failure (RPC authorization
  /// denial, malformed payload) must not wake the network every 10s for
  /// the app's entire lifetime (Phase 8: retry loop without terminal
  /// condition). Pending items are KEPT: any subsequent enqueue re-arms
  /// the timer (including the flushNow path a completed lesson takes),
  /// so a transient outage recovers on the next natural progress event.
  final int maxConsecutiveFailures;

  final Map<String, LessonProgressSyncItem> _pending = {};
  Timer? _flushTimer;
  Future<Either<Failure, void>>? _activeFlush;
  bool _isFlushing = false;
  bool _isDisposed = false;
  bool _sessionOpen = true;
  bool _discardAfterFlush = false;
  int _consecutiveFailures = 0;

  LessonProgressSyncEngine({
    required SyncLessonProgress syncLessonProgress,
    this.flushInterval = const Duration(seconds: 10),
    this.maxBatchSize = 20,
    this.maxRetryDelay = const Duration(minutes: 2),
    this.maxConsecutiveFailures = 6,
  }) : _syncLessonProgress = syncLessonProgress;

  int get pendingCount => _pending.length;

  void enqueue(LessonProgressSyncItem item, {bool flushNow = false}) {
    if (!_sessionOpen || (_isDisposed && !flushNow)) return;

    final previous = _pending[item.key];
    _pending[item.key] = previous == null ? item : previous.merge(item);

    if (flushNow ||
        _pending.length >= maxBatchSize ||
        item.completed ||
        _isDisposed) {
      // Event-driven flush: a user/completion-triggered attempt is always
      // allowed (one attempt per event), even after the retry budget below
      // has stopped the idle-timer cadence — this is the recovery path.
      unawaited(flush());
      return;
    }

    // Idle-timer flush: only arm while the failure budget allows — this is
    // the same "retry on a timer" path _scheduleRetry guards, and must not
    // bypass it (each new enqueue would otherwise re-arm a 10s retry loop
    // indefinitely while the user keeps watching during a deterministic
    // failure).
    if (_consecutiveFailures < maxConsecutiveFailures) {
      _flushTimer ??= Timer(flushInterval, () {
        _flushTimer = null;
        unawaited(flush());
      });
    }
  }

  Future<Either<Failure, void>> flush() async {
    final activeFlush = _activeFlush;
    if (activeFlush != null) {
      return activeFlush.then((_) => flush());
    }

    late final Future<Either<Failure, void>> operation;
    operation = _flushPending().whenComplete(() {
      if (identical(_activeFlush, operation)) _activeFlush = null;
    });
    _activeFlush = operation;
    return operation;
  }

  Future<Either<Failure, void>> _flushPending() async {
    if (_pending.isEmpty || _isFlushing) return const Right(null);

    _flushTimer?.cancel();
    _flushTimer = null;
    _isFlushing = true;

    final batch = _pending.values.toList(growable: false);
    _pending.clear();

    final result = await _syncLessonProgress.batch(batch);
    result.match((_) {
      // Left = flush failed → re-queue the failed items (latest-wins) and
      // count the consecutive failure toward the retry budget.
      _consecutiveFailures++;
      if (!_discardAfterFlush) {
        for (final item in batch) {
          final current = _pending[item.key];
          _pending[item.key] = current == null ? item : item.merge(current);
        }
      }
    }, (_) {
      // Right = flush succeeded → a fresh failure streak starts from zero.
      _consecutiveFailures = 0;
    });

    _isFlushing = false;
    if (_pending.isNotEmpty && !_isDisposed && _sessionOpen) {
      _scheduleRetry();
    }

    return result;
  }

  /// Arms the next retry timer with exponential backoff, or stops after
  /// [maxConsecutiveFailures] straight failures (see its doc). A timer is
  /// still armed when the budget remains but the last flush SUCCEEDED —
  /// that is the ordinary interval cadence, not a failure loop.
  void _scheduleRetry() {
    if (_flushTimer != null) return;
    if (_consecutiveFailures >= maxConsecutiveFailures) return;

    var delay = flushInterval;
    if (_consecutiveFailures > 0) {
      // flushInterval * 2^(failures-1): 10s, 20s, 40s, 80s … capped.
      delay = flushInterval * (1 << (_consecutiveFailures - 1));
      if (delay > maxRetryDelay) delay = maxRetryDelay;
    }
    _flushTimer = Timer(delay, () {
      _flushTimer = null;
      unawaited(flush());
    });
  }

  /// Flushes the current account's pending progress, then stops accepting
  /// progress and drops anything that could be retried under a future
  /// account's Supabase session.
  Future<void> closeSession({bool flushPending = false}) async {
    _sessionOpen = false;
    _flushTimer?.cancel();
    _flushTimer = null;
    _discardAfterFlush = false;
    if (flushPending) await flush();
    _discardAfterFlush = true;
    _pending.clear();
  }

  /// Opens the queue for a newly authenticated account.
  void openSession() {
    if (_isDisposed) return;
    _discardAfterFlush = false;
    _sessionOpen = true;
    // A fresh account's sync failures are independent of the previous
    // account's (e.g. an RPC denial specific to that account) — start its
    // cadence from scratch rather than inheriting an exhausted budget.
    _consecutiveFailures = 0;
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    await flush();
  }
}
