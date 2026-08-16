import '../data/log_queue.dart';
import '../domain/app_event.dart';
import '../domain/event_metadata.dart';
import '../infrastructure/sync_engine.dart';
import 'event_handler.dart';

/// Handles non-sensitive activity events: courses, videos, todos, navigation.
///
/// Writes events to [LogQueue] as plain (unencrypted) [LogEntry]s.
/// Triggers [SyncEngine] threshold check after each add.
class ActivityHandler extends EventHandler {
  final LogQueue _queue;
  final SyncEngine _syncEngine;

  ActivityHandler({
    required LogQueue queue,
    required SyncEngine syncEngine,
  })  : _queue = queue,
        _syncEngine = syncEngine;

  @override
  bool shouldHandle(AppEvent event) {
    return event.category == EventCategory.course ||
        event.category == EventCategory.video ||
        event.category == EventCategory.todo ||
        event.category == EventCategory.navigation ||
        // Low-risk offline-download events (e.g. successful playback
        // authorization). High-risk ones (e.g. playback denied) are
        // already routed to AuditHandler by risk level, not category —
        // see AuditHandler.shouldHandle.
        event.category == EventCategory.download;
  }

  @override
  void handle(AppEvent event) {
    final entry = LogEntry.fromEvent(event);
    _queue.add(entry);
    _syncEngine.onEntryAdded();
  }
}
