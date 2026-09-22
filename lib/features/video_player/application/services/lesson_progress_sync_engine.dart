import 'dart:async';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/lesson_progress_sync_item.dart';
import '../../domain/usecases/sync_lesson_progress.dart';
import 'lesson_progress_outbox_store.dart';

class LessonProgressSyncEngine {
  final SyncLessonProgress _syncLessonProgress;

  /// Disk persistence for the pending queue (Phase 9). Snapshots are
  /// written under the account id passed to [openSession] and restored only
  /// for that same account, so queued progress survives an app kill without
  /// ever being attributable to a different account. Persistence is a no-op
  /// while no account id is known (see [openSession]).
  final LessonProgressOutboxStore _outboxStore;

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
  String? _activeUserId;

  LessonProgressSyncEngine({
    required SyncLessonProgress syncLessonProgress,
    required LessonProgressOutboxStore outboxStore,
    this.flushInterval = const Duration(seconds: 10),
    this.maxBatchSize = 20,
    this.maxRetryDelay = const Duration(minutes: 2),
    this.maxConsecutiveFailures = 6,
  }) : _syncLessonProgress = syncLessonProgress,
       _outboxStore = outboxStore;

  int get pendingCount => _pending.length;

  void enqueue(LessonProgressSyncItem item, {bool flushNow = false}) {
    if (!_sessionOpen || (_isDisposed && !flushNow)) return;

    final previous = _pending[item.key];
    _pending[item.key] = previous == null ? item : previous.merge(item);
    _persistOutbox();

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

    // Whatever the outcome, the on-disk snapshot must now mirror the
    // post-flush queue: succeeded → key removed; failed → items kept for
    // the next attempt; session closed mid-flush → empty (cleared below by
    // closeSession as well).
    _persistOutbox();

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
  /// account's session — including that account's on-disk outbox snapshot,
  /// so a queued write never outlives the session that owns it.
  Future<void> closeSession({bool flushPending = false}) async {
    _sessionOpen = false;
    _flushTimer?.cancel();
    _flushTimer = null;
    _discardAfterFlush = false;
    if (flushPending) await flush();
    _discardAfterFlush = true;
    _pending.clear();
    final userId = _activeUserId;
    _activeUserId = null;
    if (userId != null) {
      try {
        await _outboxStore.clear(userId);
      } catch (e) {
        // The logout wipe removes all non-preserved preferences anyway;
        // a failed clear here must not abort the session boundary.
      }
    }
  }

  /// Opens the queue for a newly authenticated account and restores that
  /// account's on-disk outbox (progress queued by a previous session of
  /// the SAME account that ended in an app kill). Passing a different
  /// account id than the previous [closeSession]/[openSession] pair is what
  /// makes cross-account isolation hold: restore only ever reads the
  /// caller's own key. A null [userId] opens without persistence (tests,
  /// or callers without an identity) and never touches disk.
  void openSession([String? userId]) {
    if (_isDisposed) return;
    _discardAfterFlush = false;
    _sessionOpen = true;
    _activeUserId = userId;
    // A fresh account's sync failures are independent of the previous
    // account's (e.g. an RPC denial specific to that account) — start its
    // cadence from scratch rather than inheriting an exhausted budget.
    _consecutiveFailures = 0;
    if (userId != null) {
      unawaited(_restoreFromOutbox(userId));
    }
  }

  /// Phase 10 (connectivity): called when the device regains connectivity.
  ///
  /// The retry budget ([maxConsecutiveFailures]) exists to stop a timer
  /// cadence against a DETERMINISTIC failure — but an offline stretch is
  /// not deterministic, and after the budget exhausted offline, pending
  /// progress used to sit in the outbox until the next user-driven enqueue.
  /// Reconnect resets the budget and re-arms the flush; no-op when there
  /// is nothing pending or the session is closed.
  Future<void> flushOnReconnect() async {
    if (_isDisposed || !_sessionOpen || _pending.isEmpty) return;
    _consecutiveFailures = 0;
    unawaited(flush());
  }

  Future<void> _restoreFromOutbox(String userId) async {
    final List<LessonProgressSyncItem> items;
    try {
      items = await _outboxStore.load(userId);
    } catch (e) {
      // load() already guards its own failures; this only keeps a store
      // contract change from breaking session open.
      return;
    }
    // The session may have been closed, or re-opened for another account,
    // while the disk read was in flight — applying another account's (or a
    // closed session's) snapshot then would be exactly the leak this
    // design exists to prevent.
    if (!_sessionOpen || _isDisposed || _activeUserId != userId) return;
    for (final item in items) {
      final previous = _pending[item.key];
      _pending[item.key] = previous == null ? item : previous.merge(item);
    }
    if (items.isNotEmpty) {
      _persistOutbox();
      // Restored writes were acknowledged by nobody — push them to the
      // server now that the owning session is live (the RPC upsert is
      // idempotent on (user, course, lesson), so a restore-and-flush after
      // a partial earlier delivery cannot duplicate rows).
      unawaited(flush());
    }
  }

  /// Mirrors [_pending] to disk under the active account's key. No-op when
  /// no account is bound, the session is being torn down
  /// ([_discardAfterFlush] — closeSession clears the key itself), or the
  /// queue is empty-but-unbound. Fire-and-forget: a persistence failure
  /// must never break a progress enqueue or flush (the next event retries
  /// the snapshot).
  void _persistOutbox() {
    final userId = _activeUserId;
    if (userId == null || _discardAfterFlush) return;
    unawaited(
      _outboxStore
          .save(userId, _pending.values.toList(growable: false))
          .catchError((Object _) {}),
    );
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    await flush();
  }
}
