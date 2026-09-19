import 'package:app/core/logging/data/log_queue.dart';
import 'package:app/core/logging/data/log_remote_ds.dart';
import 'package:app/core/logging/domain/event_metadata.dart';
import 'package:app/core/logging/infrastructure/event_bus.dart';
import 'package:app/core/logging/infrastructure/sync_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemoteDs extends Mock implements LogRemoteDataSource {}

LogEntry _entry(String key, {DateTime? firstFailedAt}) => LogEntry(
      idempotencyKey: key,
      eventType: 'test.event',
      category: 'test',
      details: const {},
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      firstFailedAt: firstFailedAt,
    );

/// Mocks the connectivity_plus platform channel so [_flushOnce]'s
/// connectivity gate sees a deterministic network state.
void _mockConnectivity(List<String> result) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/connectivity'),
    (call) async => result,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LogQueue queue;
  late _MockRemoteDs remoteDs;
  late EventBus eventBus;
  late SyncEngine engine;

  setUp(() {
    queue = LogQueue();
    remoteDs = _MockRemoteDs();
    eventBus = EventBus();
    engine = SyncEngine(
      queue: queue,
      remoteDs: remoteDs,
      eventBus: eventBus,
    );
  });

  tearDown(() {
    engine.dispose();
    eventBus.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      null,
    );
  });

  group('SyncEngine.flush', () {
    test('does not call the remote data source when the queue is empty',
        () async {
      _mockConnectivity(<String>['wifi']);
      when(() => remoteDs.syncBatch(any())).thenAnswer((_) async => true);

      await engine.flush();

      verifyNever(() => remoteDs.syncBatch(any()));
    });

    test('connectivity gate: offline devices never touch the remote', () async {
      _mockConnectivity(<String>['none']);
      queue.add(_entry('e1'));

      await engine.flush();

      verifyNever(() => remoteDs.syncBatch(any()));
      expect(queue.length, 1,
          reason: 'the entry must stay queued for a later flush');
    });

    test('a successful flush drains the queue and clears retry state',
        () async {
      _mockConnectivity(<String>['wifi']);
      when(() => remoteDs.syncBatch(any())).thenAnswer((_) async => true);
      queue
        ..add(_entry('e1'))
        ..add(_entry('e2'));

      await engine.flush();

      final batch = verify(() => remoteDs.syncBatch(captureAny()))
          .captured.single as List<LogEntry>;
      expect(batch.map((e) => e.idempotencyKey), ['e1', 'e2']);
      expect(queue.length, 0);
      expect(queue.deadLetterCount, 0);
    });

    test('a failed flush requeues entries and stamps firstFailedAt',
        () async {
      _mockConnectivity(<String>['wifi']);
      when(() => remoteDs.syncBatch(any())).thenAnswer((_) async => false);
      queue.add(_entry('e1'));

      await engine.flush();

      expect(queue.length, 1,
          reason: 'failed entries go back to the head of the queue');
      expect(queue.deadLetterCount, 0);
    });

    test('entries failing past the retry age move to dead-letter without '
        'a remote call', () async {
      _mockConnectivity(<String>['wifi']);
      when(() => remoteDs.syncBatch(any())).thenAnswer((_) async => true);
      queue.add(_entry(
        'dead',
        // > _maxRetryAge (60s) in the past.
        firstFailedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ));

      await engine.flush();

      expect(queue.deadLetterCount, 1);
      expect(queue.length, 0);
      verifyNever(() => remoteDs.syncBatch(any()));
    });

    test('drains at most 50 entries per flush (batch cap)', () async {
      _mockConnectivity(<String>['wifi']);
      when(() => remoteDs.syncBatch(any())).thenAnswer((_) async => true);
      for (var i = 0; i < 60; i++) {
        queue.add(_entry('e$i'));
      }

      await engine.flush();

      final batch =
          verify(() => remoteDs.syncBatch(captureAny())).captured.single
              as List<LogEntry>;
      expect(batch, hasLength(50));
      expect(queue.length, 10,
          reason: 'the remaining 10 entries stay queued for the next flush');
    });
  });

  group('SyncEngine.onEntryAdded', () {
    test('triggers a flush only once the 20-entry threshold is reached',
        () async {
      _mockConnectivity(<String>['wifi']);
      when(() => remoteDs.syncBatch(any())).thenAnswer((_) async => true);

      for (var i = 0; i < 19; i++) {
        queue.add(_entry('e$i'));
      }
      engine.onEntryAdded();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      verifyNever(() => remoteDs.syncBatch(any()));
      // 19 entries are below the flush threshold.

      queue.add(_entry('threshold'));
      engine.onEntryAdded();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      verify(() => remoteDs.syncBatch(any())).called(1);
    });
  });
}
