import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../data/log_queue.dart';
import '../data/log_remote_ds.dart';
import '../domain/app_event.dart';
import '../domain/event_metadata.dart';
import 'event_bus.dart';

/// Batched sync engine that flushes [LogQueue] to Supabase.
///
/// Flush triggers:
/// - Every 10 seconds (timer)
/// - When queue reaches 20 entries (threshold)
///
/// Retry strategy (TIME-BASED):
/// - On failure: entries are re-queued at head position
/// - Each entry tracks [LogEntry.firstFailedAt]
/// - Exponential backoff on consecutive failures (10s → 20s → 40s, max 60s)
/// - Entries failing for > 60 seconds → moved to dead-letter
///
/// Self-observability:
/// - Every 30 seconds, emits [SystemMetricsEvent] with queue health
class SyncEngine {
  final LogQueue _queue;
  final LogRemoteDataSource _remoteDs;
  final EventBus _eventBus;

  Timer? _flushTimer;
  Timer? _metricsTimer;
  int _consecutiveFailures = 0;
  int _totalFlushes = 0;
  int _successfulFlushes = 0;
  bool _isFlushing = false;
  final List<int> _recentLatencies = [];

  static const _flushIntervalBase = Duration(seconds: 10);
  static const _metricsInterval = Duration(seconds: 30);
  static const _maxRetryAge = Duration(seconds: 60);
  static const _maxBackoffSeconds = 60;

  SyncEngine({
    required LogQueue queue,
    required LogRemoteDataSource remoteDs,
    required EventBus eventBus,
  })  : _queue = queue,
        _remoteDs = remoteDs,
        _eventBus = eventBus;

  /// Start the periodic flush and metrics timers.
  void start() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_flushIntervalBase, (_) => flush());

    _metricsTimer?.cancel();
    _metricsTimer = Timer.periodic(_metricsInterval, (_) => _emitMetrics());
  }

  /// Called by handlers when an entry is added to the queue.
  /// Triggers an immediate flush if the threshold is reached.
  void onEntryAdded() {
    if (_queue.shouldFlush) {
      flush();
    }
  }

  /// Flush pending entries to Supabase.
  Future<void> flush() async {
    if (_queue.length == 0 || _isFlushing) return;
    _isFlushing = true;
    try {
      await _flushOnce();
    } catch (error) {
      // A timer callback must not produce an uncaught async error. The
      // remote data source reports normal failures as false; this catches
      // unexpected failures such as a connectivity plugin exception.
      if (kDebugMode) {
        debugPrint('[SyncEngine] Flush failed: ${error.runtimeType}');
      }
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> _flushOnce() async {

    // Connectivity gate
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    // Separate expired entries → dead-letter
    final batch = _queue.drain();
    if (batch.isEmpty) return;

    final retryable = <LogEntry>[];
    final expired = <LogEntry>[];

    for (final entry in batch) {
      if (entry.isExpired(_maxRetryAge)) {
        expired.add(entry);
      } else {
        retryable.add(entry);
      }
    }

    if (expired.isNotEmpty) {
      _queue.markDeadLetter(expired);
      debugPrint('[SyncEngine] ${expired.length} entries moved to dead-letter');
    }

    if (retryable.isEmpty) return;

    _totalFlushes++;
    final stopwatch = Stopwatch()..start();
    final success = await _remoteDs.syncBatch(retryable);
    stopwatch.stop();

    if (success) {
      _consecutiveFailures = 0;
      _successfulFlushes++;
      _recentLatencies.add(stopwatch.elapsedMilliseconds);
      if (_recentLatencies.length > 20) _recentLatencies.removeAt(0);
      debugPrint('[SyncEngine] Flushed ${retryable.length} entries in ${stopwatch.elapsedMilliseconds}ms');
    } else {
      _consecutiveFailures++;

      // Mark firstFailedAt for entries that haven't failed before
      for (final entry in retryable) {
        entry.firstFailedAt ??= DateTime.now();
      }

      _queue.requeue(retryable);

      // Exponential backoff: reschedule flush timer
      final backoffSeconds = min(
        10 * pow(2, _consecutiveFailures - 1).toInt(),
        _maxBackoffSeconds,
      );
      debugPrint('[SyncEngine] Flush failed. Backoff: ${backoffSeconds}s');
      _flushTimer?.cancel();
      _flushTimer = Timer(Duration(seconds: backoffSeconds), () {
        flush();
        // Restore periodic timer
        _flushTimer = Timer.periodic(_flushIntervalBase, (_) => flush());
      });
    }
  }

  void _emitMetrics() {
    final avgLatency = _recentLatencies.isEmpty
        ? 0
        : (_recentLatencies.reduce((a, b) => a + b) / _recentLatencies.length).round();

    _eventBus.emit(SystemMetricsEvent(
      timestamp: DateTime.now(),
      queueSize: _queue.length,
      deadLetterSize: _queue.deadLetterCount,
      flushSuccessRate: _totalFlushes == 0 ? 1.0 : _successfulFlushes / _totalFlushes,
      avgFlushLatencyMs: avgLatency,
    ));
  }

  /// Stop all timers and clean up.
  void dispose() {
    _flushTimer?.cancel();
    _metricsTimer?.cancel();
  }
}
