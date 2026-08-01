import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../domain/app_event.dart';
import 'event_handler.dart';

/// Captures error events and maintains a breadcrumb trail
/// of the last 10 events for crash context enrichment.
///
/// When a [ErrorOccurredEvent] is received, the breadcrumb trail
/// is forwarded to Sentry and the error is captured.
class CrashHandler extends EventHandler {
  /// Rolling buffer of the last 10 events for crash context.
  final _breadcrumbs = Queue<String>();
  static const _maxBreadcrumbs = 10;

  @override
  bool shouldHandle(AppEvent event) {
    // Track ALL events for breadcrumb trail,
    // but only actively process system errors.
    return true;
  }

  @override
  void handle(AppEvent event) {
    // Add to breadcrumb trail
    final breadcrumb =
        '${event.activityType} @ ${event.timestamp.toIso8601String()}';
    _breadcrumbs.addLast(breadcrumb);
    if (_breadcrumbs.length > _maxBreadcrumbs) {
      _breadcrumbs.removeFirst();
    }

    // Only act on errors
    if (event is ErrorOccurredEvent) {
      _handleError(event);
    }
  }

  void _handleError(ErrorOccurredEvent event) {
    // Forward breadcrumbs to Sentry for crash context
    for (final crumb in _breadcrumbs) {
      Sentry.addBreadcrumb(Breadcrumb(message: crumb));
    }

    // Capture the error in Sentry
    Sentry.captureException(
      event.errorMessage,
      stackTrace: event.stackTrace,
    );

    if (kDebugMode) {
      debugPrint('[CrashHandler] Error: ${event.errorMessage}');
      debugPrint('[CrashHandler] Breadcrumb trail:');
      for (final crumb in _breadcrumbs) {
        debugPrint('  → $crumb');
      }
      if (event.stackTrace != null) {
        debugPrint('[CrashHandler] Stack: ${event.stackTrace}');
      }
    }
  }

  /// Get the current breadcrumb trail (for testing/debugging).
  List<String> get breadcrumbs => _breadcrumbs.toList();
}

