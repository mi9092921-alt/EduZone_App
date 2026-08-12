import '../domain/event_metadata.dart';

/// In-memory event queue with batch overflow protection and dead-letter support.
///
/// Events are held in memory until flushed by [SyncEngine].
/// No local persistence — if the app is killed, pending events are lost
/// (acceptable for non-critical analytics data).
class LogQueue {
  final List<LogEntry> _pending = [];
  final List<LogEntry> _deadLetter = [];

  /// Number of entries waiting to be flushed.
  int get length => _pending.length;

  /// Number of permanently failed entries.
  int get deadLetterCount => _deadLetter.length;

  /// Whether the queue has reached the batch flush threshold.
  bool get shouldFlush => _pending.length >= 20;

  /// Add an entry to the queue.
  ///
  /// If the queue exceeds 500 entries, the oldest 50 are dropped
  /// in a single batch removal (O(1) amortized).
  void add(LogEntry entry) {
    _pending.add(entry);
    if (_pending.length > 500) {
      _pending.removeRange(0, 50);
    }
  }

  /// Re-insert failed entries at the head of the queue for retry.
  void requeue(List<LogEntry> entries) {
    _pending.insertAll(0, entries);
  }

  /// Move permanently failed entries to the dead-letter list.
  ///
  /// Dead-letter list is capped at 100 entries for debugging/metrics.
  void markDeadLetter(List<LogEntry> entries) {
    _deadLetter.addAll(entries);
    if (_deadLetter.length > 100) {
      _deadLetter.removeRange(0, _deadLetter.length - 100);
    }
  }

  /// Atomically take up to [max] entries from the front of the queue.
  ///
  /// Returns an empty list if the queue is empty.
  List<LogEntry> drain([int max = 50]) {
    if (_pending.isEmpty) return [];
    final count = _pending.length.clamp(0, max);
    final batch = _pending.sublist(0, count);
    _pending.removeRange(0, count);
    return batch;
  }

  /// Clear all pending entries (used on logout/cleanup).
  void clear() {
    _pending.clear();
  }
}
