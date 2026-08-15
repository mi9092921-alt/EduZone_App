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
  bool _isFlushing = false;
  bool _isDisposed = false;

  LessonProgressSyncEngine({
    required SyncLessonProgress syncLessonProgress,
    this.flushInterval = const Duration(seconds: 10),
    this.maxBatchSize = 20,
  }) : _syncLessonProgress = syncLessonProgress;

  int get pendingCount => _pending.length;

  void enqueue(LessonProgressSyncItem item, {bool flushNow = false}) {
    if (_isDisposed && !flushNow) return;

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
    if (_pending.isEmpty || _isFlushing) return const Right(null);

    _flushTimer?.cancel();
    _flushTimer = null;
    _isFlushing = true;

    final batch = _pending.values.toList(growable: false);
    _pending.clear();

    final result = await _syncLessonProgress.batch(batch);
    result.match(
      (_) {
        for (final item in batch) {
          final current = _pending[item.key];
          _pending[item.key] = current == null ? item : item.merge(current);
        }
      },
      (_) {},
    );

    _isFlushing = false;
    if (_pending.isNotEmpty && !_isDisposed) {
      _flushTimer ??= Timer(flushInterval, () {
        _flushTimer = null;
        unawaited(flush());
      });
    }

    return result;
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    await flush();
  }
}
