import 'package:app/core/security/security_service.dart';
import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────────────────
// KNOWN COVERAGE GAP (documented, not silently skipped):
//
// `ScreenShareGuard.check()` (lib/core/security/guards/screen_share_guard.dart)
// starts with `if (!Platform.isAndroid) return;`. `flutter test` always
// runs on the host OS (Linux/macOS/Windows in CI, never Android), so
// `Platform.isAndroid` is unconditionally false here — the blacklist
// matching logic and the `SecurityService._onThreatDetected(...)` call it
// can trigger are structurally unreachable from any unit test as written.
//
// This is a real, permanent gap, not a missing mock: reaching that branch
// would require either (a) an injectable `Platform`/`InstalledApps`
// abstraction (architectural change, needs sign-off), or (b) an
// integration/instrumented test running on an actual Android
// device/emulator, which is outside the scope of `flutter test`.
// ─────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScreenShareGuard.check()', () {
    test(
      'returns immediately without throwing on a non-Android host '
      '(the only branch reachable from flutter test)',
      () async {
        await expectLater(ScreenShareGuard.check(), completes);
      },
    );

    test('can be called multiple times without throwing', () async {
      await expectLater(ScreenShareGuard.check(), completes);
      await expectLater(ScreenShareGuard.check(), completes);
    });
  });
}
