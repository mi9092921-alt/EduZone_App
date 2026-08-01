import 'package:flutter/foundation.dart';

import '../domain/app_event.dart';
import 'event_handler.dart';

/// Lightweight analytics handler for future Firebase/Mixpanel integration.
///
/// In debug mode: logs events to console via [debugPrint].
/// In release mode: no-op (zero overhead).
class AnalyticsHandler extends EventHandler {
  @override
  bool shouldHandle(AppEvent event) {
    // Handle all events in debug mode for development visibility.
    // In release, skip system metrics to reduce noise.
    if (kReleaseMode && event is SystemMetricsEvent) return false;
    return true;
  }

  @override
  void handle(AppEvent event) {
    if (kDebugMode) {
      debugPrint(
        '[Analytics] ${event.activityType} '
        '| risk=${event.riskLevel.name} '
        '| entity=${event.entityId}',
      );
    }
    // ignore: todo
    // TODO: Forward to Firebase Analytics / Mixpanel when integrated
    // FirebaseAnalytics.instance.logEvent(name: event.activityType, parameters: event.details);
  }
}
