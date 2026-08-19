import 'package:app/core/logging/domain/app_event.dart';
import 'package:app/core/logging/handlers/event_handler.dart';
import 'package:app/core/logging/infrastructure/event_bus.dart';
import 'package:app/core/logging/infrastructure/event_dispatcher.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

class _ThrowingHandler extends EventHandler {
  @override
  bool shouldHandle(AppEvent event) => true;

  @override
  void handle(AppEvent event) => throw StateError('boom');
}

class _RecordingHandler extends EventHandler {
  final received = <AppEvent>[];

  @override
  bool shouldHandle(AppEvent event) => true;

  @override
  void handle(AppEvent event) => received.add(event);
}

void main() {
  test(
    'a throwing handler does not prevent later handlers from receiving the event',
    () async {
      final throwing = _ThrowingHandler();
      final recording = _RecordingHandler();
      final dispatcher = EventDispatcher([throwing, recording]);
      final bus = EventBus();
      addTearDown(bus.dispose);
      addTearDown(dispatcher.dispose);

      dispatcher.start(bus.stream);

      bus.emit(
        ScreenViewedEvent(timestamp: DateTime(2026), screenName: 'home'),
      );

      // EventBus broadcasts asynchronously via its own stream controller.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        recording.received,
        hasLength(1),
        reason:
            'Regression guard: one handler throwing must not stop the '
            'dispatcher from reaching subsequent handlers for the same '
            'event (Section 15 pipeline resilience).',
      );
    },
  );
}
