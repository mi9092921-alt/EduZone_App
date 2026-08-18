# integration_test — Section 16 coverage status and remaining gaps

This tracks `integration_test/app_test.dart` against the minimum integration-test
flow list in `Production EduZone App — Agent Instructions.md`, Section 16.

## Newly added in this pass (verified statically, not yet run — see note below)

- **Localization + RTL**: `switching locale to Arabic renders an RTL layout
  with localized strings` — overrides `appLocaleProvider` to `Locale('ar')`
  and asserts `Directionality.of(context) == TextDirection.rtl` plus the
  Arabic `loginTitle` string, using the app's real `MaterialApp.router`
  locale wiring in `main_app.dart` (no fake `Directionality` wrapper).
- **Accessibility**: `login screen meets minimum tap-target and
  text-contrast accessibility guidelines` — uses `tester.ensureSemantics()`
  plus Flutter's built-in `meetsGuideline(textContrastGuideline)` and
  `meetsGuideline(labeledTapTargetGuideline)` matchers against the real
  rendered Semantics tree. This is the actual widget-level accessibility
  test Section 17 asks for ("do not limit accessibility checks to
  `IconButton.tooltip`"), not a static source-text check.

Both tests were added to the existing scenario/container pattern already
used by the six prior tests (`_containerFor`, `_pumpApp`, `_pumpUntil`) so
they carry the same guarantees and the same risk profile as the tests
already accepted into this suite.

**Important caveat**: this container/sandbox has no Flutter SDK and no
network access, so `flutter test integration_test/app_test.dart` could not
actually be executed here. Both new tests were written against the real
provider/widget signatures in this repo (`appLocaleProvider`, `LoginScreen`,
`AppLocalizationsAr`, `MaterialApp.router` locale plumbing) and mirror the
exact structure of the six pre-existing, presumably-passing tests, but they
are **statically inspected, not run-verified**. Run them first in CI/local
before relying on them as a release gate. If `meetsGuideline` fails, treat
that as a **real accessibility finding** to fix (e.g. a contrast or tap
target issue on the login screen), not a bug in the test.

## Still missing (Section 16 minimum list) — needs a dedicated follow-up pass

These require deeper, feature-specific fixture/provider wiring
(`getMyCoursesProvider`, `getCourseDetailsProvider`,
`updateLessonProgressProvider`, the `downloads_provider.dart` /
`download_manager` stack, offline policy engine, video player controller
lifecycle) that should be reviewed file-by-file before writing tests against
them — the same "understand before changing" discipline this project
requires for production code applies to test code too. Adding tests against
guessed provider signatures risks shipping integration tests that don't
compile or, worse, pass for the wrong reason.

- [ ] Course loading (`getMyCoursesProvider` / home → courses list)
- [ ] Course details (`getCourseDetailsProvider`)
- [ ] Lesson playback flow (video player screen + controller lifecycle)
- [ ] Progress tracking (`updateLessonProgressProvider` + sync engine)
- [ ] Notifications interaction (beyond the existing provider override —
      no test currently taps/reads a notification end-to-end)
- [ ] Download flow (request → authorize → download → ready state)
- [ ] Offline access / offline playback path
- [ ] Retry behavior beyond the `AuthDegraded` case already covered (e.g.
      network retry on course/list load failure)

## Recommended order for the follow-up pass

1. `courses`: `getMyCoursesProvider` → home → course list → course details
   (lowest risk: read-only, no encryption/background-worker surface).
2. `notifications`: read/mark-as-read against the existing
   `notificationsProvider` override already used in `_containerFor`.
3. `video_player`: lesson playback start/pause, grounded in
   `test/features/video_player/**` unit tests already covering the
   controller/provider layer in isolation.
4. `downloads` + offline access: highest risk/complexity (background
   workers, encryption, device binding per
   `EduZone_Offline_Download_Security_Trusted_Playback_Architecture.md`) —
   do this last, after P6-A audit tasks from that document are further
   along, so the integration test reflects the real (not aspirational)
   security boundary.
