# core/security — fixed bugs and remaining structural gaps

## Bugs fixed (approved and applied)

1. **`_logThreatToSupabase()` now catches `AssertionError` too**
   (`security_service.dart`). `Supabase.instance` throws `AssertionError`
   before `Supabase.initialize()` has run, not `StateError` as the
   original code assumed — the `'supabase_not_ready'` branch was
   previously dead code.

2. **`LifecycleGuard.didChangeAppLifecycleState()` now `await`s its
   native calls** (`lifecycle_guard.dart`). Previously, native failures
   from `ScreenProtector.protectDataLeakageOn/Off()` leaked as unhandled
   async errors instead of being caught by the surrounding try/catch —
   reliably corrupting unrelated test results, and a real risk of
   confusing production crash reports.

3. **`SecurityService.init()` now skips the freeRASP startup step
   cleanly** via the new `isFreeraspConfigured()` check
   (`freerasp_config.dart`) whenever `SECURITY_ANDROID_SIGNING_HASH` is
   empty in a non-release build — confirmed to be every local build,
   since the team does not currently supply `.env.security`. Previously
   this let freerasp's own `AndroidConfig` constructor throw a
   `configuration-exception`, logged as a confusing generic startup
   failure. Release-build behavior (fail fast if genuinely misconfigured)
   is unchanged.

See `security_service_test.dart`, `guards/lifecycle_guard_test.dart`, and
`freerasp_config_test.dart` for the tests covering each fix directly.

## Remaining structural gaps (need an architectural decision, not a bug fix)

### 1. `freerasp_config.dart` — Talsec wiring itself untestable as structured

- `_setupFreeraspListener()` and the real `Talsec.instance.start(...)`
  call are only reachable via a real native plugin — the actual freeRASP
  threat-detection callbacks (onRoot, onHooks, onDebug, onSimulator,
  etc.) can never be invoked from a unit test.
- `_getTalsecConfig()`'s release-mode fail-fast check can never actually
  run under `flutter test`, because `kReleaseMode` is always `false` in
  the test runner and cannot be forced `true`.
- **Minimal fix, if wanted** (needs sign-off): inject a thin wrapper
  interface around `Talsec.instance` that `SecurityService` depends on
  instead of the static singleton directly.

### 2. `ScreenShareGuard.check()` — blacklist-matching branch unreachable

- `check()` returns immediately unless `Platform.isAndroid` is true.
  `flutter test` always runs on the host OS, so the actual
  blacklist-matching loop and the `SecurityService._onThreatDetected(...)`
  call it can trigger are structurally unreachable from a unit test.
- **Minimal fix, if wanted** (needs sign-off): inject the platform check
  and/or the `InstalledApps` lookup behind a testable seam, or accept
  this as integration-test-only coverage (requires a real Android
  device/emulator, outside `flutter test`'s scope).

## What IS covered

- `SecurityService.init()`'s public contract: completes cleanly with an
  **empty** threat buffer in a normal local/CI test environment — no
  false-positive startup failures (this is the corrected behavior after
  fix #3).
- `isFreeraspConfigured()`: correctly returns `false` for the team's
  actual local-dev configuration (no `.env.security`).
- `LifecycleGuard` and `ScreenshotGuard`: never throw or leak an async
  error even without a mocked native channel, for every relevant
  lifecycle state.
- `ScreenShareGuard.check()`'s only branch reachable outside Android.
