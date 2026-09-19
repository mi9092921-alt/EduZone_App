import 'package:app/core/logging/domain/app_event.dart';
import 'package:app/core/logging/infrastructure/event_bus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late EventBus bus;

  setUp(() {
    bus = EventBus();
  });

  tearDown(() {
    bus.dispose();
  });

  AuthLoginEvent loginEvent({int ms = 1000}) => AuthLoginEvent(
        timestamp: DateTime.fromMillisecondsSinceEpoch(ms),
      );

  group('EventBus', () {
    test('delivers an emitted event to a subscriber', () async {
      final received = <AppEvent>[];
      final sub = bus.stream.listen(received.add);

      bus.emit(loginEvent());
      await pumpEventQueue();

      expect(received, hasLength(1));
      expect(received.single, isA<AuthLoginEvent>());
      await sub.cancel();
    });

    test('is broadcast: multiple handlers each receive the same event',
        () async {
      final first = <AppEvent>[];
      final second = <AppEvent>[];
      final sub1 = bus.stream.listen(first.add);
      final sub2 = bus.stream.listen(second.add);

      bus.emit(loginEvent());
      await pumpEventQueue();

      expect(first, hasLength(1));
      expect(second, hasLength(1));
      await sub1.cancel();
      await sub2.cancel();
    });

    test(
        'drops a duplicate idempotencyKey emitted within the dedup window',
        () async {
      final received = <AppEvent>[];
      final sub = bus.stream.listen(received.add);

      // Same type + same timestamp (ms) + same entityId => same
      // idempotencyKey (md5 of type:timestamp:entityId).
      bus.emit(loginEvent());
      bus.emit(loginEvent());
      await pumpEventQueue();

      expect(received, hasLength(1),
          reason: 'the second identical event must be silently deduplicated');
      await sub.cancel();
    });

    test('delivers events with different idempotency keys', () async {
      final received = <AppEvent>[];
      final sub = bus.stream.listen(received.add);

      bus.emit(loginEvent());
      bus.emit(loginEvent(ms: 2000));
      await pumpEventQueue();

      expect(received, hasLength(2));
      await sub.cancel();
    });

    test('emit after dispose is a silent no-op (no throw)', () async {
      bus.dispose();

      expect(() => bus.emit(loginEvent()), returnsNormally);
    });
  });
}
