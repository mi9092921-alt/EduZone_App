import 'dart:async';

import '../domain/app_event.dart';

/// The single entry point for all application events.
///
/// Uses a broadcast [StreamController] so multiple handlers
/// can listen simultaneously. Includes a 2-second deduplication
/// window to prevent double-tap / rapid re-render duplicates.
class EventBus {
  final _controller = StreamController<AppEvent>.broadcast();
  final Set<String> _recentKeys = {};
  Timer? _cleanupTimer;

  EventBus() {
    // Clean up dedup keys every 2 seconds
    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _recentKeys.clear(),
    );
  }

  /// The event stream that handlers listen to.
  Stream<AppEvent> get stream => _controller.stream;

  /// Emit an event into the pipeline.
  ///
  /// Events with duplicate [AppEvent.idempotencyKey] within the
  /// 2-second dedup window are silently dropped.
  void emit(AppEvent event) {
    if (_controller.isClosed) return;
    if (_recentKeys.contains(event.idempotencyKey)) return;

    _recentKeys.add(event.idempotencyKey);
    _controller.add(event);
  }

  /// Dispose the stream controller and cleanup timer.
  void dispose() {
    _cleanupTimer?.cancel();
    _controller.close();
  }
}
