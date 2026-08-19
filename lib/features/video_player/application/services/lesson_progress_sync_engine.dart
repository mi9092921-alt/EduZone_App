import 'dart:async';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/lesson_progress_sync_item.dart';
import '../../domain/usecases/sync_lesson_progress.dart';

class LessonProgressSyncEngine {
  final SyncLessonProgress _syncLessonProgress;
  final Duration flushInterval;
  final int maxBatchSize;

  final Map<String, LessonProgressSyncItem> _pending = {};
  Timer? _flushTimer;
  Future<Either<Failure, void>>? _activeFlush;
  bool _isFlushing = false;
  bool _isDisposed = false;
  bool _sessionOpen = true;
  bool _discardAfterFlush = false;

  LessonProgressSyncEngine({
    required SyncLessonProgress syncLessonProgress,
    this.flushInterval = const Duration(seconds: 10),
    this.maxBatchSize = 20,
  }) : _syncLessonProgress = syncLessonProgress;

  int get pendingCount => _pending.length;

  void enqueue(LessonProgressSyncItem item, {bool flushNow = false}) {
    if (!_sessionOpen || (_isDisposed && !flushNow)) return;

    final previous = _pending[item.key];
    _pending[item.key] = previous == null ? item : previous.merge(item);

    if (flushNow || _pending.length >= maxBatchSize || item.completed || _isDisposed) {
      unawaited(flush());
      return;
    }

    _flushTimer ??= Timer(flushInterval, () {
      _flushTimer = null;
      unawaited(flush());
    });
  }

  Future<Either<Failure, void>> flush() async {
    final activeFlush = _activeFlush;
    if (activeFlush != null) return activeFlush;

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
    result.match(
      (_) {
        if (!_discardAfterFlush && _sessionOpen) {
          for (final item in batch) {
            final current = _pending[item.key];
            _pending[item.key] = current == null ? item : item.merge(current);
          }
        }
      },
      (_) {},
    );

    _isFlushing = false;
    if (_pending.isNotEmpty && !_isDisposed && _sessionOpen) {
      _flushTimer ??= Timer(flushInterval, () {
        _flushTimer = null;
        unawaited(flush());
      });
    }

    return result;
  }

  /// Stops accepting progress for the ended account and drops anything that
  /// could otherwise be retried under a future account's Supabase session.
  void closeSession() {
    _sessionOpen = false;
    _discardAfterFlush = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    _pending.clear();
  }

  /// Opens the queue for a newly authenticated account.
  void openSession() {
    if (_isDisposed) return;
    _discardAfterFlush = false;
    _sessionOpen = true;
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    await flush();
  }
}
