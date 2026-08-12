import '../domain/app_event.dart';

/// Base class for all event handlers in the logging pipeline.
///
/// Each handler declares which events it can handle via [shouldHandle],
/// and processes them in [handle]. Handlers must be non-blocking
/// and must never throw — errors should be caught internally.
abstract class EventHandler {
  /// Whether this handler should process the given [event].
  bool shouldHandle(AppEvent event);

  /// Process the event. Must not throw.
  void handle(AppEvent event);
}
