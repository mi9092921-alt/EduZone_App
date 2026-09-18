import 'package:app/core/logging/domain/app_event.dart';
import 'package:app/core/logging/handlers/crash_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CrashHandler.shouldHandle', () {
    test('handles every event, not only errors, to build breadcrumb context', () {
      final handler = CrashHandler();
      expect(
        handler.shouldHandle(
          ScreenViewedEvent(timestamp: DateTime(2026), screenName: 'home'),
        ),
        isTrue,
      );
      expect(
        handler.shouldHandle(
          ErrorOccurredEvent(timestamp: DateTime(2026), errorMessage: 'boom'),
        ),
        isTrue,
      );
    });
  });

  group('CrashHandler breadcrumb trail', () {
    test('caps at the last 10 events', () {
      final handler = CrashHandler();
      for (var i = 0; i < 15; i++) {
        handler.handle(
          ScreenViewedEvent(
            timestamp: DateTime(2026),
            screenName: 'screen-$i',
          ),
        );
      }
      expect(handler.breadcrumbs.length, 10);
      // Oldest entries should have rolled off.
      expect(handler.breadcrumbs.first, contains('screen-5'));
      expect(handler.breadcrumbs.last, contains('screen-14'));
    });

    test('does not throw when handling an ErrorOccurredEvent (Sentry no-op in tests)', () {
      final handler = CrashHandler();
      expect(
        () => handler.handle(
          ErrorOccurredEvent(
            timestamp: DateTime(2026),
            errorMessage: 'Login failed: errorGeneric',
            stackTrace: 'fake-stack',
          ),
        ),
        returnsNormally,
      );
    });
  });

  group('ErrorOccurredEvent expected flag', () {
    test('defaults to expected=false and surfaces it in details', () {
      final unexpected = ErrorOccurredEvent(
        timestamp: DateTime(2026),
        errorMessage: 'boom',
      );
      expect(unexpected.expected, isFalse);
      expect(unexpected.details['expected'], isFalse);
    });

    test('an expected outcome carries expected=true in details', () {
      final expected = ErrorOccurredEvent(
        timestamp: DateTime(2026),
        errorMessage: 'Login failed: errorMaxDevices',
        expected: true,
      );
      expect(expected.expected, isTrue);
      expect(expected.details['expected'], isTrue);
    });
  });
}
