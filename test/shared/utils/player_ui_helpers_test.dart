import 'package:app/shared/utils/player_ui_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlayerProgressReporter', () {
    test('reports immediately on the first call', () {
      final now = DateTime(2026);
      DateTime clock() => now;
      final reporter = PlayerProgressReporter.withClock(now: clock);

      expect(reporter.shouldReport(Duration.zero), isTrue);
    });

    test('suppresses reports within the interval', () {
      var now = DateTime(2026);
      DateTime clock() => now;
      final reporter = PlayerProgressReporter.withClock(now: clock);

      expect(reporter.shouldReport(Duration.zero), isTrue);

      now = now.add(const Duration(seconds: 4));
      expect(reporter.shouldReport(Duration.zero), isFalse);
    });

    test('reports again once the interval has elapsed', () {
      var now = DateTime(2026);
      DateTime clock() => now;
      final reporter = PlayerProgressReporter.withClock(now: clock);

      expect(reporter.shouldReport(Duration.zero), isTrue);

      now = now.add(const Duration(seconds: 5));
      expect(reporter.shouldReport(Duration.zero), isTrue);
    });

    test('reset() allows an immediate report again', () {
      var now = DateTime(2026);
      DateTime clock() => now;
      final reporter = PlayerProgressReporter.withClock(now: clock);

      expect(reporter.shouldReport(Duration.zero), isTrue);

      now = now.add(const Duration(seconds: 1));
      reporter.reset();
      expect(reporter.shouldReport(Duration.zero), isTrue);
    });

    test('honors a custom interval', () {
      var now = DateTime(2026);
      DateTime clock() => now;
      final reporter = PlayerProgressReporter.withClock(
        interval: const Duration(seconds: 1),
        now: clock,
      );

      expect(reporter.shouldReport(Duration.zero), isTrue);

      now = now.add(const Duration(milliseconds: 999));
      expect(reporter.shouldReport(Duration.zero), isFalse);

      now = now.add(const Duration(milliseconds: 1));
      expect(reporter.shouldReport(Duration.zero), isTrue);
    });
  });

  group('AutoHideControlsTimer', () {
    // Real (short) delays instead of fake_async: the package is only a
    // transitive dependency here, and importing it directly would trip
    // depend_on_referenced_packages. The margins below are wide enough
    // to be stable on slow CI.
    test('fires onHide after the delay', () async {
      var hid = false;
      final timer = AutoHideControlsTimer(
        delay: const Duration(milliseconds: 20),
        onHide: () => hid = true,
      );

      timer.restart();
      await Future<void>.delayed(const Duration(milliseconds: 2));
      expect(hid, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(hid, isTrue);
    });

    test('cancel() prevents the pending hide from firing', () async {
      var hid = false;
      final timer = AutoHideControlsTimer(
        delay: const Duration(milliseconds: 20),
        onHide: () => hid = true,
      );

      timer.restart();
      timer.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(hid, isFalse);
    });

    test('restart() reschedules, replacing any pending hide', () async {
      var hideCount = 0;
      final timer = AutoHideControlsTimer(
        delay: const Duration(milliseconds: 40),
        onHide: () => hideCount++,
      );

      timer.restart();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      timer.restart();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      // Only 10ms of the second schedule elapsed: nothing fired yet, and
      // the first (now-superseded) schedule never fired either.
      expect(hideCount, 0);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(hideCount, 1);
    });

    test('dispose() cancels like cancel()', () async {
      var hid = false;
      final timer = AutoHideControlsTimer(
        delay: const Duration(milliseconds: 20),
        onHide: () => hid = true,
      );

      timer.restart();
      timer.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(hid, isFalse);
    });
  });
}
