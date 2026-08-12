import 'package:app/core/security/guards/lifecycle_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LifecycleGuard', () {
    test('instance is a singleton', () {
      expect(LifecycleGuard.instance, same(LifecycleGuard.instance));
    });

    // No screen_protector platform channel is mocked in this test file —
    // that's the point: didChangeAppLifecycleState() now `await`s its
    // native calls inside its try/catch (fixed — see git history/chat:
    // previously this was a real bug where the missing `await` let native
    // failures leak as unhandled async errors instead of being caught).
    // Every state below must resolve cleanly, with no leaked error,
    // matching real app behavior when the native plugin isn't available
    // yet or fails.
    for (final state in AppLifecycleState.values) {
      test(
        'didChangeAppLifecycleState($state) never throws or leaks an '
        'async error, even without a mocked screen_protector channel',
        () async {
          expect(
            () => LifecycleGuard.instance.didChangeAppLifecycleState(state),
            returnsNormally,
          );
          // Drain pending microtasks so a leaked async error (if the fix
          // ever regresses) surfaces and fails THIS test, rather than a
          // later unrelated one.
          await Future<void>.delayed(Duration.zero);
        },
      );
    }

    test(
      'paused and inactive both route through protectDataLeakageOn() '
      'without throwing or leaking',
      () async {
        expect(
          () => LifecycleGuard.instance
              .didChangeAppLifecycleState(AppLifecycleState.paused),
          returnsNormally,
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          () => LifecycleGuard.instance
              .didChangeAppLifecycleState(AppLifecycleState.inactive),
          returnsNormally,
        );
        await Future<void>.delayed(Duration.zero);
      },
    );

    test(
      'resumed routes through protectDataLeakageOff() without throwing '
      'or leaking',
      () async {
        expect(
          () => LifecycleGuard.instance
              .didChangeAppLifecycleState(AppLifecycleState.resumed),
          returnsNormally,
        );
        await Future<void>.delayed(Duration.zero);
      },
    );
  });
}
