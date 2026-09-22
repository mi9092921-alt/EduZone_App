import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/global_error_handler.dart';
import '../../domain/entities/lesson_progress_sync_item.dart';

/// Disk-backed persistence for [LessonProgressSyncEngine]'s pending queue.
///
/// The sync queue is in-memory only, so an app kill (no logout, no dispose)
/// silently dropped every not-yet-acknowledged progress write — unsynced
/// watch progress vanished without a trace (Phase 9 "no silent data loss").
/// This store snapshots the pending map under the signed-in account's key
/// (`progress_outbox_v1_<userId>`), so the next session opened for the SAME
/// account restores and re-flushes them. Account isolation is structural:
/// a session opened for a different user loads a different (empty) key, and
/// a session close deletes the owner's key, so no item can ever be flushed
/// under another account's session.
///
/// Storage is SharedPreferences — the outbox holds only progress deltas
/// (course/lesson ids, percentages), never tokens or credentials, and is
/// bounded (see [_maxItems]) so a runaway enqueue loop cannot grow it.
class LessonProgressOutboxStore {
  static const String _keyPrefix = 'progress_outbox_v1_';
  static const int _schemaVersion = 1;

  /// Upper bound on restored items. The engine itself batches at 20 and the
  /// pending map is bounded in practice by distinct (course, lesson) pairs
  /// touched since the last successful flush; this only guards a corrupted
  /// or hostile on-disk payload from ballooning a restore.
  static const int _maxItems = 500;

  String _key(String userId) => '$_keyPrefix$userId';

  /// Serializes all store operations. Enqueue-persists are fire-and-forget
  /// while closeSession awaits its clear, so without ordering a persist
  /// that was already in flight could land AFTER the clear and resurrect a
  /// session's outbox on disk after its own logout boundary. Chaining
  /// every operation through one queue makes the last-issued operation the
  /// last to touch the key.
  Future<void> _opQueue = Future.value();

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _opQueue.then((_) => operation());
    _opQueue = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  /// Loads the given account's queued items. Any structural damage
  /// (malformed JSON, wrong schema version, unexpected field types) is
  /// logged, the damaged key is deleted, and an EMPTY queue is returned —
  /// the outbox is a write-ahead queue, not a source of truth, so a
  /// corrupted entry is discarded rather than guessed at (the server
  /// remains authoritative for actual progress).
  Future<List<LessonProgressSyncItem>> load(String userId) {
    return _serialized(() async {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(userId));
      if (raw == null) return const <LessonProgressSyncItem>[];

      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('outbox payload is not an object');
        }
        if (decoded['v'] != _schemaVersion) {
          throw const FormatException('unsupported outbox schema version');
        }
        final items = decoded['items'];
        if (items is! List) {
          throw const FormatException('outbox items is not a list');
        }
        final restored = <LessonProgressSyncItem>[];
        for (final entry in items) {
          final item = _decodeItem(entry);
          if (item != null && restored.length < _maxItems) {
            restored.add(item);
          }
        }
        return restored;
      } on FormatException catch (e, st) {
        GlobalErrorHandler.logError(e, st);
        debugPrint(
          '[LessonProgressOutbox] corrupted outbox for $userId discarded: $e',
        );
        await prefs.remove(_key(userId));
        return const <LessonProgressSyncItem>[];
      } catch (e, st) {
        GlobalErrorHandler.logError(e, st);
        debugPrint(
          '[LessonProgressOutbox] unreadable outbox for $userId discarded: '
          '${e.runtimeType}',
        );
        await prefs.remove(_key(userId));
        return const <LessonProgressSyncItem>[];
      }
    });
  }

  /// Replaces the account's outbox with [items]. An empty list removes the
  /// key entirely so no stale file lingers after a clean flush.
  Future<void> save(String userId, List<LessonProgressSyncItem> items) {
    return _serialized(() async {
      final prefs = await SharedPreferences.getInstance();
      if (items.isEmpty) {
        await prefs.remove(_key(userId));
        return;
      }
      final payload = jsonEncode({
        'v': _schemaVersion,
        'items': [
          for (final item in items.take(_maxItems)) _encodeItem(item),
        ],
      });
      await prefs.setString(_key(userId), payload);
    });
  }

  Future<void> clear(String userId) {
    return _serialized(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId));
    });
  }

  Map<String, dynamic> _encodeItem(LessonProgressSyncItem item) => {
    'courseId': item.courseId,
    'lessonId': item.lessonId,
    'completed': item.completed,
    'progressPct': item.progressPct,
    if (item.watchTimeSec != null) 'watchTimeSec': item.watchTimeSec,
  };

  /// Returns null for any entry whose required fields are missing or of the
  /// wrong type — a single bad row is skipped instead of poisoning the
  /// whole restore.
  LessonProgressSyncItem? _decodeItem(dynamic entry) {
    if (entry is! Map) return null;
    final courseId = entry['courseId'];
    final lessonId = entry['lessonId'];
    final completed = entry['completed'];
    final progressPct = entry['progressPct'];
    final watchTimeSec = entry['watchTimeSec'];
    if (courseId is! String ||
        lessonId is! String ||
        completed is! bool ||
        progressPct is! num) {
      return null;
    }
    if (watchTimeSec != null && watchTimeSec is! int) return null;
    return LessonProgressSyncItem(
      courseId: courseId,
      lessonId: lessonId,
      completed: completed,
      progressPct: progressPct.toDouble(),
      watchTimeSec: watchTimeSec as int?,
    );
  }
}
