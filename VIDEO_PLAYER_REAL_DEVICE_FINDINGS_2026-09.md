# Real-device video player findings — 2026-09-26

## Scope

The first YouTube player was checked against the connected Android device:

- Device: `CPH2269`
- Android: 11 / API 30
- Architecture: `android-arm64`
- Package: `com.eduzone.learn.app`

This note separates issues in the YouTube widget from issues in lesson
navigation, content loading, connectivity, or the device/runtime.

## Finding 1 — generic error appears below the video after selecting a lesson

### Evidence

The supplied device screenshot shows:

1. The current lesson title and a working YouTube frame at the top.
2. Player controls and the normal lesson action row below it.
3. A generic `حدث خطأ غير متوقع` state underneath.

The first-player route is composed in `lib/app/router/app_router.dart`. It
loads `lessonContentProvider(lessonId)` and maps provider errors to
`_VideoLessonError`, which renders the generic error state. Selecting a lesson
from the same section calls `context.replace(...)` from
`lib/features/video_player/presentation/widgets/lessons_sidebar.dart`.

### Assessment

This is outside the YouTube rendering/control layer. The likely boundary is
one of:

- `get_lesson_content` failing for the newly selected lesson;
- a transient Supabase/session/network failure during the route replacement;
- a route-transition or stale-page layering issue that leaves the previous
  player visible while the replacement route renders its error state.

### Pending reproduction

Reproduce with a logged-in account on a stable network and capture, for the
same lesson switch:

- the lesson ID before and after `context.replace`;
- the `lessonContentProvider` exception type/code;
- the Supabase `get_lesson_content` response/error;
- the final GoRouter location and active page stack.

Do not change the YouTube widget to mask this error.

### Fix applied after code review

The route no longer calls `context.replace` immediately on a sidebar tap. The
next lesson's `lessonContentProvider` is resolved first; only a successful
result replaces the current route. A failure leaves the current video mounted,
shows the localized retry message, and invalidates the failed family instance
so the next attempt starts cleanly. Repeated taps are blocked while this
prefetch is in flight.

The `get_lesson_content` RPC contract was checked against both the Flutter
decoder and `supabase/schema/07_functions.sql`: the returned fields match the
`LessonContent` model, and the client already uses `NetworkGuard.read` with a
bounded timeout and transient retry. No SQL, RLS, or authorization change was
justified by the evidence, so none was made.

## Finding 5 — orientation toggle and vertical layout

The installed `youtube_player_flutter 9.1.3` implementation copies
`aspectRatio` in `initState` and does not refresh it in `didUpdateWidget`. The
old reference path supplied for comparison was not present in this workspace,
so this conclusion was verified against the package source in the local Pub
cache and the current app code.

The first player previously passed the changing ratio only into the package,
while its parent `Column` had no app-owned height bound for the vertical mode.
The fix gives the package a tight externally-owned surface, caps the normal
vertical surface at 52% of the viewport, and leaves fullscreen unconstrained.
This prevents the sidebar's `Expanded` child from losing its layout space and
avoids recreating the YouTube controller during orientation changes.

## Finding 2 — connectivity state was inconsistent during the report

### Evidence

The device accessibility tree contained the global `لا يوجد اتصال بالإنترنت`
notice while the player frame was visible. A subsequent Android connectivity
check reported the Wi‑Fi network as `VALIDATED` (`WE_1C0CCD`). The app owns this
notice in `lib/shared/providers/network_banner_provider.dart` and
`lib/shared/widgets/network_banner.dart`.

### Assessment

This is outside the YouTube player. It may be a stale/missed
`connectivity_plus` transition, or the lesson-content request may have failed
even though the link later became validated. Keep it as a separate
connectivity/content-loading investigation.

## Finding 3 — startup frame loss on the test device

The Android log for the debug run reported:

```text
Skipped 226 frames! The application may be doing too much work on its main thread.
```

The same run also emitted OEM graphics messages and a VP9 decoder line. This
was observed during app startup/initialization, not isolated to a YouTube
position tick, so it is not yet evidence that the first player is the cause.
Profile the player after the lesson is loaded before changing playback code.

## Finding 4 — current workspace APK cannot reach the authenticated lesson

The debug launch from this workspace was blocked before the lesson flow:

```text
CRITICAL INITIALIZATION ERROR: StateError
Bad state: Supabase credentials are empty!
Build with: flutter run --dart-define-from-file=.env
```

The installed device build also had a different Android signing key, so Flutter
reported `INSTALL_FAILED_UPDATE_INCOMPATIBLE` and removed the old installation
before installing the debug APK. That cleared the old authenticated session.
This is a local build/test setup issue, not a YouTube-player failure. A valid
device run must use the project `.env` through the approved local launch
configuration and a matching signing key or a deliberate test reset.

## Subtitle status

The screenshot contains Arabic text inside the video area. The first-player
code disables YouTube captions through `enableCaption: false` and now retries
the iframe suppression at readiness and on meaningful player-state changes,
using both `unloadModule('captions')` and `unloadModule('cc')`. It does not poll
the WebView on every playback tick, and installs one CSS rule inside the
YouTube iframe as a fallback for caption DOM rendered after module restore. The
patched build could not be fully
exercised through the authenticated lesson flow because the local launch lacked
Supabase credentials; the package-signature mismatch also required an uninstall,
clearing the prior app session.

If the text remains after a fresh authenticated run, compare the same video in
the YouTube web player. If it remains in the image itself, it is burned into
the uploaded video and cannot be removed by the Flutter player.

## Next investigation order

1. Install the successful debug APK on the authenticated real-device build and
   test horizontal/vertical toggle plus same-section lesson switching.
2. If a switch still fails, capture the exact `lessonContentProvider` error
   type/code and the final router location; the current route now keeps the
   previous lesson visible for that failure class.
3. Profile YouTube playback after content loading succeeds; the layout fix is
   separate from the previously observed startup frame skips.

## Verification after the fix

- `flutter test test/features/video_player/presentation/screens/video_player_screen_test.dart`
  passed all 5 tests.
- `flutter build apk --debug --no-pub` completed successfully and produced
  `build/app/outputs/flutter-apk/app-debug.apk`.
- `flutter analyze` was attempted but remained in analyzer initialization with
  no diagnostics; it was stopped after the build and focused tests passed.

## Real-device run — 2026-09-26

### Installation and environment

- Device: `CPH2269`, serial `VGOZ9T69SCUKWCDI`, Android 11 / API 30.
- The environment-configured debug APK was rebuilt and installed with
  `adb install -r`; the existing app data was preserved.
- Installed package reports version `1.3.0` and the process started normally.
- Wi-Fi was `VALIDATED`; a device-side ping to `8.8.8.8` succeeded at about
  241 ms. No `get_lesson_content`, Postgrest, RPC, or network exception was
  found in this run.

### Errors reproduced in the app process

1. **Provider mutation during build**

   Flutter logged `Tried to modify a provider while the widget tree was
   building`. The stack identifies:

   - `VideoProgress.seedFromServer`
   - `_VideoPlayerScreenState.initState`

   This is a confirmed app lifecycle bug, independent of YouTube and the
   network. The server progress seeding is currently writing to Riverpod from
   `initState`.

2. **Layout overflow**

   Flutter logged `A RenderFlex overflowed by 279 pixels on the bottom` while
   the lesson screen was being mounted. This confirms the earlier layout
   finding on the real device; the log did not include a render-object stack,
   so the exact child still needs a focused layout trace after the provider
   lifecycle error is removed.

3. **Frame loss**

   The same run logged `Skipped 82 frames`. A GC pause of about 447 ms was also
   observed in the app process. This is a device/runtime performance finding,
   not evidence of a YouTube RPC failure.

### Manual-control limitation

The app process remained alive and accepted input, but this device returned a
zero-byte screenshot through `adb screencap`, and its UIAutomator tree exposed
only the Flutter root `FrameLayout` (no Flutter semantics nodes). Therefore the
orientation tap could not be visually confirmed through ADB in this session;
no new Flutter error appeared immediately after the attempted tap. The
existing mirroring window is required for final visual confirmation.

## Follow-up after root fixes — 2026-09-26

### Code fixes applied

- Moved `VideoProgress.seedFromServer` out of `initState` into a guarded
  post-frame callback. This removes the confirmed Riverpod mutation-during-
  build error without weakening the monotonic server-progress rule.
- Kept the player in one stable `AppScreen`/flex slot for normal and fullscreen
  modes. The parent now supplies an explicit finite surface size, including
  fullscreen, so platform-view layout cannot receive an unbounded height.
- Kept the YouTube surface externally sized for orientation changes, capped the
  normal vertical mode, and retained the fullscreen exit control.
- Deferred `MediaKit.ensureInitialized()` until `player4` or offline playback
  is actually opened. YouTube no longer pays the libmpv startup cost.

### Verification after these changes

- The debug APK rebuilt successfully and installed over the connected
  `CPH2269` device with `adb install -r`.
- The focused video-player screen tests passed (5/5).
- The player4/offline widget test groups passed (55/55).
- No provider-mutation, RenderFlex-overflow, or RPC/PostgREST error appeared
  during the latest post-install startup sample before entering a lesson.

### Remaining device findings outside the first YouTube player

- The device still reports long startup stalls (`Skipped 376 frames` in the
  latest sample, with OEM ANR diagnostics). This run restored/entered a native
  player route, so libmpv was then initialized lazily as designed; this is an
  app bootstrap/native-player performance issue, not a YouTube caption or
  orientation contract.
- The device also reported low storage and OEM-only messages such as
  `libEGL` path warnings and `Parcel` null-string warnings. They are not
  actionable Flutter player exceptions in the app code.
- ADB still exposes no Flutter semantics tree and returns an unusable
  zero-byte screenshot on this device. Consequently, the final visual check
  of the first YouTube player's exit button, captions, and same-section lesson
  tap still requires the existing screen-mirroring window. The code/build and
  widget regressions are covered; no network/RPC change was justified by the
  captured evidence.

## Baseline re-measurement — 2026-09-26 (before the launch-blocker fixes)

Fresh debug build (`flutter build apk --debug --dart-define-from-file=.env`)
installed after an uninstall/reinstall cycle (signing key mismatch again —
`INSTALL_FAILED_UPDATE_INCOMPATIBLE`, same as the earlier session, so the
on-device session was cleared and login was redone).

Device state during the run: ~3.1 GB free storage (94% used), MemFree ~119 MB
of 3.9 GB — heavy background memory pressure, several LM-kill sweeps visible
in logcat (messaging, Play Store, camera processes died during the session).

Timeline (captured from a full `adb logcat` recording, saved as
`build/baseline_logcat.txt`, timestamps local):

- `17:07:26` cold start: `Skipped 620 frames` + `Skipped 108` + `Skipped 142`
  on the app main thread (debug build — consistent with, and worse than, the
  documented 226/82 baseline, most plausibly due to the low-MemFree state).
- `17:10:32` → `17:11:01` a lesson was played successfully for ~28.5 s
  (`AudioTrack` created, `start()` from `STATE_STOPPED`, then `stop()` after
  1,370,112 frames @ 48 kHz — usage=MEDIA). No `libmpv` process activity, so
  this was the WebView-based (YouTube) player.
- `17:11:31` **ANR reproduced**: `tombstoned` collected a Java-backtrace
  intercept for the app pid; the traced sample shows the app at 145% CPU
  (main thread 91% user) with 139,280 minor / 223 major page faults. The
  WebView `sandboxed_process0` died right before the kill.
- `17:11:52` process killed — `Killing <pid>:com.eduzone.learn.app (adj 0):
  user request after error` — i.e. the ANR dialog was acknowledged and the
  app was closed. This is direct live evidence for the documented
  "Skipped frames + OEM ANR" release blocker.
- `17:12:31` relaunch: `[FeatureFlags] refreshed: 6/7 registered flags in
  6792ms` — flag refresh took ~6.8 s on this network (documented ~241 ms
  ping environment).

Confirmed absent in this run: no `RenderFlex overflow`, no `FATAL
EXCEPTION`, no Flutter-level exception in the captured window.

Baseline accepted for the fix round: cold start 620/108/142 skipped frames,
lesson playback functional (28.5 s), ANR during post-playback interaction
reproduced once. The after-fix round must re-measure the same sequence.

## Launch-blocker fix round — 2026-09-26 (same day, same device)

### What was fixed (code)

1. **YouTube error handling (launch-blocker #1)** — `youtube_error_mapper.dart`
   (new) maps IFrame error codes to localized copy; `_YoutubePlayerWrapperState`
   now checks `value.hasError` BEFORE the readiness gate (IFrame errors can
   fire before/instead of onReady) and renders a full-bleed localized error
   view with a controller-recreating retry. No new l10n keys.
2. **App-lifecycle pause (launch-blocker #2)** — all three online wrappers
   (YouTube / Player4 / Modern) now mix in `WidgetsBindingObserver` and stop
   playback on `paused`/`inactive`, no auto-resume — mirroring
   `OfflinePlayerWrapper` policy and iOS (no `audio` UIBackgroundModes entry).
   Modern player gained a guarded `pauseVideo()` JS hook in the generated
   document.
3. **Modern player cleanup sweep** throttled 40ms → 400ms (was 25 full DOM
   sweeps/second for the whole lesson), pinned by test.
4. **Player4 release-log hygiene** — the three ungated `debugPrint`s in
   `_handlePlayerError` are now `kDebugMode`-gated.
5. **player4_remote_ds.dart doc drift** — comment now states `lesson_id` is
   REQUIRED by the live `video-info` function (HTTP 400 when absent).

### Root cause of the ANR blocker — identified with hard evidence

Second baseline run (17:43–17:46) reproduced the ANR again and this time the
Dart-side evidence was captured. The freeze chain, all in debug mode:

1. `17:45:15.781` — `RenderFlex children have non-zero flex but incoming
   height constraints are unbounded`. Culprit identified from the printed
   creator chain: the bottom-controls
   `Positioned(bottom/left/right) → Column` in `youtube_player_widget.dart`,
   whose `ProgressBar(isExpanded: true)` wraps itself in an `Expanded`
   (VERTICAL flex) inside a bottom-pinned positioned child — which by
   construction receives unbounded height. This assert had been latent since
   the initial commit; it was caught-and-logged, normally survivable.
2. `17:45:15.969` — follow-on `hasSize` assertion
   (`RenderBox was not laid out: RenderFlex`) in the same frame.
3. `17:45:16.061` — `!childSemantics.renderObject._nee...` assertion inside
   `_RenderObjectSemantics._collectChildMergeUpAndSiblingGroup` → mutual
   recursion with `updateChildren`/`_didUpdateParentData` (frames #2…#68+)
   → main thread wedged → ANR dialog (17:45:33 stack collection) → process
   killed `user request after error` (17:45:55).

**Fix:** `ProgressBar(isExpanded: false)` (default) — the bar is already
full-width through the positioned child's tight width (the package's
`_buildBar` uses `BoxConstraints.expand`); the `Expanded` only ever asked
for vertical expansion, which was never the intent and is illegal under
unbounded height. This removes the trigger for the whole chain.

### Post-fix verification (18:00–18:05, same device, same debug build config)

- Single app process for the whole round — no restarts, **zero ANR, zero
  RenderFlex/flex assertions, zero provider-mutation errors** (was: ANR on
  both previous rounds at the fullscreen step).
- Fullscreen enter + rotate + exit — the exact previous freeze point —
  completed cleanly; progress bar renders normally (user visual check via
  mirroring).
- **Background-pause verified with audio-track evidence**: three playback
  sessions (`AudioTrack` sessions 59145/59153/59161) each show
  `start → stop (prior state: STATE_ACTIVE)` exactly when the user pressed
  Home — audio stops immediately on backgrounding, matching the new
  lifecycle observer. Return-to-foreground leaves playback paused (no
  auto-resume) as designed.
- Same-section lesson switching via sidebar: 15 navigation events, no
  `lessonContentProvider` errors.
- Skipped-frames profile (max 686/389/219 at cold start, debug build,
  device at 94% storage / low free RAM) remains in the same band as the
  documented baseline — the ANR trigger is gone; the startup/WebView frame
  cost on this low-end device remains open profiling work (profile-mode
  measurement recommended before any optimization claim).

### Deferred / environment-blocked items from this round

- **Player4 device verification** — requires the external extraction
  service (yt-dlp/Python) on the backend, unavailable in the dev
  environment during this round. The lifecycle pause for Player4 is
  covered by code review + the identical pattern verified live on the
  YouTube and Modern players.
- **Wrapper State widget tests (review item #6)** — deferred: needs a
  small injectability refactor (Player factory for Player4Wrapper); the
  mapper and HTML-generation logic added in this round are unit-tested
  (youtube_error_mapper_test, modern_player_html_test additions).
- iOS device round (blocker #4) — still out of scope on this Windows host.

### Release build smoke (same round)

- `flutter clean` → `flutter build apk --release --dart-define-from-file=.env
  --target-platform android-arm64` succeeded (89.4 MB) after the test
  sessions (per the project's clean-before-release rule).
- Installed (required an uninstall — release signing differs from debug,
  session cleared again) and launched: process alive after 40 s with zero
  `FATAL`/ANR entries — R8/minification does not break app bootstrap.
- **Pending:** one authenticated lesson-playback check inside the release
  build (WebView under R8) was offered for a manual pass but not completed
  in this round; treat release-mode lesson playback as unverified until
  that single check is done.

### CLOSED — release-mode lesson playback (was pending above)

Confirmed 2026-09-26 by the operator on the same device: logged into the
installed release APK and played a YouTube lesson — video and audio
playback normal. Corroborated by logcat: app process alive for the whole
session (pid 15459) with zero `FATAL EXCEPTION`/`ANR in com.eduzone`
entries in the buffer. R8/minification does not break WebView playback.

With this check, the Android-side launch checklist items that were
executable in this environment are all closed. Remaining open items are
exactly the ones documented above: Player4 device round (needs the
backend extraction service), wrapper State widget tests (injectability
refactor), and the iOS device round (no host).
