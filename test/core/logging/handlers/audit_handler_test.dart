import 'package:app/core/logging/data/log_queue.dart';
import 'package:app/core/logging/data/log_remote_ds.dart';
import 'package:app/core/logging/domain/app_event.dart';
import 'package:app/core/logging/handlers/audit_handler.dart';
import 'package:app/core/logging/infrastructure/event_bus.dart';
import 'package:app/core/logging/infrastructure/log_encryption_service.dart';
import 'package:app/core/logging/infrastructure/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

/// Fake encryption service that lets each test force success or failure
/// without touching FlutterSecureStorage.
class FakeLogEncryptionService implements LogEncryptionService {
  FakeLogEncryptionService({this.shouldThrow = false});

  final bool shouldThrow;

  @override
  Future<String> encrypt(String plaintext) async {
    if (shouldThrow) {
      throw StateError('secure storage unavailable');
    }
    return 'v1:fake-iv:fake-ciphertext';
  }

  @override
  Future<String> decrypt(String ciphertext) async => 'unused-in-tests';
}

void main() {
  late LogQueue queue;
  late SyncEngine syncEngine;
  late EventBus eventBus;

  setUp(() {
    queue = LogQueue();
    eventBus = EventBus();
    // The queue never reaches the 20-entry flush threshold in these
    // tests, so SyncEngine.onEntryAdded() never triggers a real
    // network flush -- the remote data source is never actually
    // invoked. A plain mock client is enough to satisfy the
    // constructor.
    syncEngine = SyncEngine(
      queue: queue,
      remoteDs: LogRemoteDataSource(MockSupabaseClient()),
      eventBus: eventBus,
    );
  });

  tearDown(() {
    eventBus.dispose();
    syncEngine.dispose();
  });

  /// Auth events are always routed to AuditHandler (see
  /// AuditHandler.shouldHandle), and carry a `reason` that is exactly
  /// the kind of security-relevant content this handler exists to
  /// encrypt before it ever leaves the device.
  AuthAccessDeniedEvent makeSensitiveEvent() => AuthAccessDeniedEvent(
        timestamp: DateTime(2026),
        userId: 'user-123',
        tenantId: 'tenant-1',
        deviceId: 'device-1',
        reason: 'device_mismatch: expected=abc got=xyz',
      );

  group('AuditHandler.shouldHandle', () {
    test('handles auth-category events regardless of risk level', () {
      final handler = AuditHandler(
        queue: queue,
        syncEngine: syncEngine,
        encryptionService: FakeLogEncryptionService(),
      );
      expect(handler.shouldHandle(makeSensitiveEvent()), isTrue);
    });
  });

  group('AuditHandler — encryption succeeds', () {
    test('queues an encrypted entry and never carries plaintext details', () async {
      final handler = AuditHandler(
        queue: queue,
        syncEngine: syncEngine,
        encryptionService: FakeLogEncryptionService(),
      );

      handler.handle(makeSensitiveEvent());
      // handle() is fire-and-forget; let the microtask queue settle.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(queue.length, 1);
      final entry = queue.drain().single;

      expect(entry.isEncrypted, isTrue);
      // The raw sensitive `reason` string must never appear anywhere
      // in the entry shipped off-device.
      expect(entry.details.toString(), isNot(contains('device_mismatch')));
      expect(entry.details, containsPair('encrypted', isA<String>()));
    });
  });

  group('AuditHandler — encryption fails (fail-closed)', () {
    test(
      'does NOT ship the plaintext sensitive details when encryption throws',
      () async {
        final handler = AuditHandler(
          queue: queue,
          syncEngine: syncEngine,
          encryptionService: FakeLogEncryptionService(shouldThrow: true),
        );

        handler.handle(makeSensitiveEvent());
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(queue.length, 1);
        final entry = queue.drain().single;

        // Regression guard for the fail-open bug: previously the
        // fallback path shipped `LogEntry.fromEvent(event)` verbatim,
        // i.e. the *actual* plaintext `reason` field, to Supabase.
        expect(
          entry.details.toString(),
          isNot(contains('device_mismatch')),
          reason:
              'Section 15 fail-closed requirement: encryption failure '
              'must never fall back to shipping plaintext sensitive '
              'audit details.',
        );
        expect(entry.isEncrypted, isFalse);
        expect(entry.details['_redacted'], isTrue);

        // The event still surfaces as having happened (type/category/
        // risk/ids preserved) so ops retain observability.
        expect(entry.eventType, 'auth.access_denied');
        expect(entry.userId, 'user-123');
      },
    );
  });
}
