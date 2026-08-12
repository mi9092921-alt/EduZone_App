import 'package:app/core/security/guards/screenshot_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScreenshotGuard.protect()', () {
    test(
      'completes without throwing even without a mocked '
      'screen_protector channel',
      () async {
        // No platform channel mock is registered — this reproduces a
        // native plugin failure/unavailability, which is exactly the
        // scenario protect()'s internal try/catch exists to survive.
        // App startup (SecurityService.init()'s "Screenshot protection"
        // step) must never be blocked or crashed by this call.
        await expectLater(ScreenshotGuard.protect(), completes);
      },
    );

    test('can be called multiple times without throwing', () async {
      await expectLater(ScreenshotGuard.protect(), completes);
      await expectLater(ScreenshotGuard.protect(), completes);
    });
  });
}
