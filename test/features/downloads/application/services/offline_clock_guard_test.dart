import 'package:app/features/downloads/application/services/offline_clock_guard.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockFlutterSecureStorage secureStorage;

  setUpAll(() {
    registerFallbackValue('');
  });

  setUp(() {
    secureStorage = MockFlutterSecureStorage();
  });

  group('OfflineClockGuard — no secure storage (degraded mode)', () {
    test('never throws and is a no-op when no backend is supplied', () async {
      final guard = OfflineClockGuard();
      await guard.checkAndRecord(now: DateTime(2020, 1, 1));
      await guard.checkAndRecord(now: DateTime(2010, 1, 1)); // "rollback"
      // No exception — degraded mode cannot detect anything.
    });
  });

  group('OfflineClockGuard — first observation', () {
    test('persists the watermark on first call and does not throw', () async {
      when(() => secureStorage.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);
      when(() => secureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      final guard = OfflineClockGuard(secureStorage: secureStorage);
      final now = DateTime(2026, 1, 1);
      await guard.checkAndRecord(now: now);

      verify(() => secureStorage.write(
            key: 'offline_clock_anchor_ms',
            value: now.millisecondsSinceEpoch.toString(),
          )).called(1);
    });
  });

  group('OfflineClockGuard — forward progress', () {
    test('advances the watermark and does not throw when time moves forward',
        () async {
      final anchor = DateTime(2026, 1, 1);
      when(() => secureStorage.read(key: any(named: 'key'))).thenAnswer(
        (_) async => anchor.millisecondsSinceEpoch.toString(),
      );
      when(() => secureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      final guard = OfflineClockGuard(secureStorage: secureStorage);
      final later = anchor.add(const Duration(days: 5));
      await guard.checkAndRecord(now: later);

      verify(() => secureStorage.write(
            key: 'offline_clock_anchor_ms',
            value: later.millisecondsSinceEpoch.toString(),
          )).called(1);
    });

    test('within tolerance behind the watermark does not throw and does not '
        'rewrite it', () async {
      final anchor = DateTime(2026, 1, 10);
      when(() => secureStorage.read(key: any(named: 'key'))).thenAnswer(
        (_) async => anchor.millisecondsSinceEpoch.toString(),
      );

      final guard = OfflineClockGuard(secureStorage: secureStorage);
      final slightlyBehind = anchor.subtract(const Duration(hours: 1));
      await guard.checkAndRecord(now: slightlyBehind);

      verifyNever(() => secureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ));
    });
  });

  group('OfflineClockGuard — rollback detection (P6.16)', () {
    test('throws when the clock is rolled back beyond tolerance', () async {
      final anchor = DateTime(2026, 6, 1);
      when(() => secureStorage.read(key: any(named: 'key'))).thenAnswer(
        (_) async => anchor.millisecondsSinceEpoch.toString(),
      );

      final guard = OfflineClockGuard(secureStorage: secureStorage);
      final rolledBack = anchor.subtract(const Duration(days: 30));

      await expectLater(
        guard.checkAndRecord(now: rolledBack),
        throwsA(isA<ClockRollbackSuspectedException>()),
      );

      // A rollback attempt must never move the watermark backward.
      verifyNever(() => secureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ));
    });
  });

  group('OfflineClockGuard — secure storage failures', () {
    test('degrades silently (no throw) when read fails', () async {
      when(() => secureStorage.read(key: any(named: 'key')))
          .thenThrow(Exception('platform error'));

      final guard = OfflineClockGuard(secureStorage: secureStorage);
      await guard.checkAndRecord(now: DateTime(2026, 1, 1));
    });

    test('degrades silently (no throw) when write fails', () async {
      when(() => secureStorage.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);
      when(() => secureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenThrow(Exception('platform error'));

      final guard = OfflineClockGuard(secureStorage: secureStorage);
      await guard.checkAndRecord(now: DateTime(2026, 1, 1));
    });
  });
}
