# integration_test — Section 16 coverage status and remaining gaps

This tracks `integration_test/app_test.dart` against the minimum integration-test
flow list in `Production EduZone App — Agent Instructions.md`, Section 16.

## Newly added in this pass (verified statically, not yet run — see note below)

- **Course loading** (`getMyCoursesProvider` / `myCoursesProvider`): the
  home→courses shell tab now loads `MyCoursesScreen`, renders a fixture
  enrollment/course, and tapping the course tile navigates into
  `CourseDetailsScreen` at `/courses/:courseId` — closing the first item on
  the "still missing" list below.
- **Notifications interaction**: opens `NotificationsScreen` via
  `/home/notifications`, renders a fixture notification, and taps
  "Mark all read" end-to-end through to a fake `NotificationsRepository`,
  asserting the call carries the authenticated user's id. This closes the
  second item on the "still missing" list below.
  - This required a small production fix, not just a test: **`NotificationsScreen`
    read `SupabaseService.client.auth.currentUser?.id` directly inside its
    "Mark all read" `onPressed` handler**, bypassing the app's own
    `authProvider` and requiring a live, initialized Supabase client to
    exercise from any widget/integration test — a violation of Section 6
    ("Do NOT put database/network/storage code directly inside UI
    screens") and the reason this action was explicitly *not* tested
    anywhere in the repo before this pass (see the removed NOTE in
    `test/features/notifications/presentation/screens/notifications_screen_test.dart`).
    Fixed by sourcing the user id from `ref.read(authProvider)` instead,
    the same testable source every other screen already uses. See
    `lib/features/notifications/presentation/screens/notifications_screen.dart`.
    A dedicated authenticated/unauthenticated pair of widget tests was also
    added to `notifications_screen_test.dart` to lock this in at the
    widget-test layer, not just the integration-test layer.

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

- [x] Course loading (`getMyCoursesProvider` / home → courses list) — done
      this pass.
- [x] Course details (`getCourseDetailsProvider`) — covered by the same new
      test (tap-through from `MyCoursesScreen` into `CourseDetailsScreen`).
      Deeper `CourseDetailsScreen` states (enroll footer, tabs, sections)
      already have dedicated widget-test coverage in
      `test/features/courses/presentation/screens/course_details_screen_test.dart`;
      the integration test only proves the navigation seam.
- [ ] Lesson playback flow (video player screen + controller lifecycle)
- [ ] Progress tracking (`updateLessonProgressProvider` + sync engine)
- [x] Notifications interaction — done this pass (see above), including the
      "Mark all read" tap end-to-end.
- [ ] Download flow (request → authorize → download → ready state)
- [ ] Offline access / offline playback path
- [ ] Retry behavior beyond the `AuthDegraded` case already covered (e.g.
      network retry on course/list load failure)

## Recommended order for the follow-up pass

1. ~~`courses`: `getMyCoursesProvider` → home → course list → course details~~
   Done this pass.
2. ~~`notifications`: read/mark-as-read against the existing
   `notificationsProvider` override already used in `_containerFor`.~~
   Done this pass.
3. `video_player`: lesson playback start/pause, grounded in
   `test/features/video_player/**` unit tests already covering the
   controller/provider layer in isolation.
4. `downloads` + offline access: highest risk/complexity (background
   workers, encryption, device binding per
   `EduZone_Offline_Download_Security_Trusted_Playback_Architecture.md`) —
   do this last, after P6-A audit tasks from that document are further
   along, so the integration test reflects the real (not aspirational)
   security boundary.

## Still not run

Same caveat as the previous pass: this container/sandbox has no Flutter SDK
and no network access, so none of the tests in this file — old or new —
could actually be executed here (`flutter test integration_test/app_test.dart`
and `flutter test test/features/notifications/presentation/screens/notifications_screen_test.dart`
must be run in CI/local before relying on any of them as a release gate).
They were written against the real provider/widget/repository signatures in
this repo and mirror the structure of the existing, presumably-passing
tests, but they are **statically inspected, not run-verified**.
