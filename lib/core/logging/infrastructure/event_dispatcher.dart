import 'dart:async';

import '../domain/app_event.dart';
import '../handlers/event_handler.dart';

/// Routes events from [EventBus] to registered [EventHandler]s.
///
/// Each handler declares which events it can handle via [shouldHandle].
/// Events are dispatched synchronously to all matching handlers.
class EventDispatcher {
  final List<EventHandler> _handlers;
  StreamSubscription<AppEvent>? _subscription;

  EventDispatcher(this._handlers);

  /// Start listening to the event stream and dispatching.
  void start(Stream<AppEvent> stream) {
    _subscription?.cancel();
    _subscription = stream.listen(_dispatch);
  }

  void _dispatch(AppEvent event) {
    for (final handler in _handlers) {
      if (handler.shouldHandle(event)) {
        try {
          handler.handle(event);
        } catch (_) {
          // Never let a handler crash take down the event pipeline
        }
      }
    }
  }

  /// Stop listening and clean up.
  void dispose() {
    _subscription?.cancel();
  }
}
