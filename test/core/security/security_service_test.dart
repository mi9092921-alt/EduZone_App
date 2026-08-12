import 'package:app/core/security/security_service.dart';
import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────────────────
// KNOWN COVERAGE GAP (documented, not silently skipped — see also
// test/core/security/README_TEST_GAPS.md):
//
// `SecurityService.init()` calls `Talsec.instance.start(...)` directly
// with no injectable abstraction around it, so the actual freeRASP
// threat-detection callbacks can never be invoked from a unit test.
// `_killApp()` / `_onThreatDetected()` are therefore also untested here.
//
// Additionally, after the three fixes below, none of init()'s three
// startup steps naturally fail in a clean local/CI test environment
// anymore (that was the point of fixing them) — which means
// `_logThreatToSupabase()`'s AssertionError-catch fix (see #1) has no
// natural trigger left in this test file to exercise directly. That is
// an acceptable, expected outcome for error-handling code: it should
// only run on genuine unexpected failures, and forcing one artificially
// here would test a scenario that no longer reflects reality.
// ─────────────────────────────────────────────────────────────────────────
//
// THREE BUGS FIXED (were discovered while first writing this test suite;
// fixed after explicit approval — team confirmed .env.security is not
// supplied locally, which is what made #3 a real, everyday issue rather
// than a theoretical one):
//
// 1. `_logThreatToSupabase()` now catches both `StateError` AND
//    `AssertionError` — `Supabase.instance` actually throws the latter
//    before initialization, so the specific `'supabase_not_ready'`
//    status is reachable now (previously dead code; fell through to the
//    generic `'unknown_error'` branch).
//
// 2. `LifecycleGuard.didChangeAppLifecycleState()` now `await`s its
//    ScreenProtector calls inside the try/catch, so native failures are
//    actually caught instead of leaking as unhandled async errors. See
//    guards/lifecycle_guard_test.dart.
//
// 3. `SecurityService.init()` now skips the freeRASP startup step
//    cleanly (one informational debugPrint, not a threat-buffer entry)
//    whenever SECURITY_ANDROID_SIGNING_HASH is empty in a non-release
//    build — via the new `isFreeraspConfigured()` check in
//    freerasp_config.dart — instead of running it and letting freerasp's
//    own AndroidConfig constructor throw a confusing
//    "configuration-exception: signingCertHashes cannot be empty".
//    Release-build behavior (fail fast if genuinely misconfigured) is
//    unchanged. See freerasp_config_test.dart.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecurityService.init()', () {
    // NOTE: `SecurityService` uses static singleton state (`_initialized`)
    // that persists for the lifetime of this test file's VM. Only the
    // FIRST test that calls init() observes the "fresh" startup path.

    test(
      'completes cleanly with an EMPTY threat buffer in a normal '
      'local/CI test environment — no false-positive startup failures '
      '(this is the corrected behavior; see the three fixes documented '
      'above)',
      () async {
        await expectLater(SecurityService.init(), completes);

        expect(
          SecurityService.unsyncedThreatBuffer,
          isEmpty,
          reason:
              'All three startup steps should now either succeed or skip '
              'cleanly with no signing hash configured: screenshot '
              'protection catches its own native-plugin failure '
              'internally, the screen-share scan no-ops on a non-Android '
              'host, and freeRASP is skipped outright via '
              'isFreeraspConfigured() rather than failing.',
        );
      },
    );

    test(
      'is idempotent — a second call short-circuits and does not change '
      'the (empty) threat buffer',
      () async {
        final before = SecurityService.unsyncedThreatBuffer.length;
        await expectLater(SecurityService.init(), completes);
        expect(SecurityService.unsyncedThreatBuffer.length, before);
      },
    );
  });

  group('SecurityService.unsyncedThreatBuffer', () {
    test('is exposed as an unmodifiable view', () {
      expect(
        () => SecurityService.unsyncedThreatBuffer.add(const {}),
        throwsUnsupportedError,
      );
    });
  });

  group('SecurityService.killAppHandler', () {
    test('can be set and invoked without throwing', () {
      String? handledReason;
      SecurityService.killAppHandler = (reason) {
        handledReason = reason;
      };

      expect(SecurityService.killAppHandler, isNotNull);
      SecurityService.killAppHandler!('Test threat');
      expect(handledReason, equals('Test threat'));

      // Clean up after test
      SecurityService.killAppHandler = null;
    });
  });
}
