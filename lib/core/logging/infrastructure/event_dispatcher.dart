import 'dart:async';

import 'package:flutter/foundation.dart';

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
        } catch (e) {
          // Never let one handler's failure take down the pipeline for
          // the remaining handlers (e.g. a bug in AnalyticsHandler must
          // not stop AuditHandler from still encrypting/queuing a
          // security-relevant event for the same AppEvent). Swallowing
          // this *silently* would itself violate Section 15 ("Audit:
          // ... unexpected exceptions") by making failures inside the
          // logging pipeline itself invisible -- surface the exception
          // type locally in debug builds. Deliberately not forwarded to
          // Sentry/CrashHandler here: CrashHandler is one of the
          // handlers this loop calls, so reporting its own failures
          // through itself risks recursion.
          if (kDebugMode) {
            debugPrint(
              '[EventDispatcher] Handler ${handler.runtimeType} threw '
              '${e.runtimeType} handling ${event.activityType}',
            );
          }
        }
      }
    }
  }

  /// Stop listening and clean up.
  void dispose() {
    _subscription?.cancel();
  }
}
