# Implementation Notes

Scoped, tagged notes referenced from inline code comments elsewhere in the
repo. This file documents *only* what's actually implemented and verifiable
from the source today — not a general engineering handbook. If you're
looking for architecture rationale, see the individual `EduZone_*.md`
design docs; this file is deliberately narrower.

---

## REL-001 — Android release signing

**Referenced from:** `android/app/build.gradle.kts`

### What happens today

`android/app/build.gradle.kts` looks for `android/key.properties` at build
time:

- **If present:** the `release` build type is signed with the real
  production keystore described in that file.
- **If absent or incomplete:** the `release` build fails immediately with a
  Gradle error. There is no debug-keystore fallback for release artifacts.

`android/key.properties` and `*.keystore` / `*.jks` files are git-ignored
(see `.gitignore`) — they are never committed, by design.

### Generating a real production keystore (one-time, per signing identity)

```bash
keytool -genkey -v \
  -keystore eduzone-release.keystore \
  -alias eduzone \
  -keyalg RSA -keysize 2048 -validity 10000
```

Store the resulting `.keystore` file and its passwords in your own secret
manager (password manager, CI secrets store, etc.) — this repository has
no opinion on which one.

### Creating `android/key.properties`

Create the file locally (never commit it):

```properties
storeFile=/absolute/path/to/eduzone-release.keystore
storePassword=<your store password>
keyAlias=eduzone
keyPassword=<your key password>
```

### Wiring it into CI (CI-001)

The CI quality job deliberately performs a debug APK smoke build using the
non-secret `.env.example`. It does not claim to verify production release
signing. Actual production signing is verified only by the explicit Android
deploy/release path with real signing secrets.

`deploy.yml`'s `deploy_android` job is the one that actually needs a real
signed build, and writes `android/key.properties` + decodes the keystore
from CI secrets itself (`ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`).
**Status: wired but unverified** — if any required secret is missing, the
workflow now fails closed instead of reporting a skipped deployment as a
success. The first real workflow run against valid secrets is still required
for release verification.

### Getting the SHA-256 signing hash for `SECURITY_ANDROID_SIGNING_HASH`

Required separately by `lib/core/security/freerasp_config.dart` (see
`.env.security.example`) so freeRASP can detect a repackaged/resigned APK:

```bash
keytool -list -v -keystore eduzone-release.keystore -alias eduzone | grep SHA256
```

---

## FB-001 — Firebase / FCM push notification configuration

**Referenced from:** `android/app/build.gradle.kts`,
`lib/features/notifications/data/services/fcm_service.dart`,
`.github/workflows/deploy.yml`

### The original report

A production Sentry event (EDUZONE-3) showed a non-fatal `PlatformException`
on every launch: *"Failed to load FirebaseOptions from resource. Check that
you have defined values.xml correctly."*, raised from
`Firebase.initializeApp()` inside `FcmService.init()`.

### Root cause

Two independent things were both true:

1. `firebase_core` / `firebase_messaging` were declared in `pubspec.yaml`
   and `Firebase.initializeApp()` was called, but the
   `com.google.gms.google-services` Gradle plugin was **never applied**
   anywhere in the Android project. That plugin is what reads
   `android/app/google-services.json` at build time and generates the
   `values.xml` resources (`google_app_id`, `google_api_key`,
   `default_web_client_id`, etc.) that native `FirebaseApp`
   auto-initialization reads at runtime. Without the plugin applied, those
   resources never exist — so even a machine with a real, valid
   `google-services.json` in place still failed with exactly this error on
   every single launch.
2. `google-services.json` is intentionally git-ignored (see `.gitignore`)
   — it's per-Firebase-project configuration, not committed — and nothing
   in CI ever supplied one, so no build (local or CI) ever had the file
   present in the first place.

### What happens today

- `android/app/build.gradle.kts` applies the `google-services` plugin only
  when `android/app/google-services.json` exists on disk at build time; if
  it's absent, Gradle logs a warning and the build proceeds with Firebase
  Messaging disabled. This keeps `flutter build`/CI quality checks working
  on a checkout with no Firebase project wired up.
- `FcmService.init()` already wraps the whole Firebase/FCM bootstrap in a
  try/catch: a failure here is logged to Sentry via `GlobalErrorHandler`
  and leaves `_initialized = false` for a later retry, but never crashes
  the app or blocks startup. This was already true before FB-001 and is
  why the original Sentry event was `level: error`, not a fatal crash —
  push notifications simply didn't work on that install.
- `deploy.yml`'s `deploy_android` job now has a non-blocking
  `GOOGLE_SERVICES_JSON` secret check (see CI-001 below): if the secret is
  absent, the deploy still proceeds (this is a product gap, not a
  signing/security one, so it isn't fail-closed like REL-001), but a
  `⚠️ Firebase not configured for this release` warning is written to the
  GitHub Actions step summary so it can't be missed the way a
  Gradle-log-only warning can be.

### Providing a real `google-services.json`

1. In the [Firebase console](https://console.firebase.google.com/), add an
   Android app with package name `com.eduzone.learn.app` to the project
   backing this app's push notifications.
2. Download the generated `google-services.json`.
3. For local development: place it at `android/app/google-services.json`
   (git-ignored, never commit it).
4. For CI/release builds: set its exact file contents as the
   `GOOGLE_SERVICES_JSON` repository secret (raw JSON text, same pattern
   as the existing `PLAY_STORE_JSON_KEY` secret — no base64 needed).

### Wiring it into CI (CI-001)

`deploy.yml`'s `deploy_android` job writes
`android/app/google-services.json` from the `GOOGLE_SERVICES_JSON` secret
immediately before `flutter build appbundle`, alongside the existing
signing/env secret writes. **Status: wired but unverified** — the secret
does not exist in the repo yet (see "Known gaps" below), and like the rest
of `deploy_android`, no CI run has ever exercised this path end-to-end.

### Honest scope of this fix

This closes the code-side crash-reproduction path and the CI provisioning
gap. It does **not** by itself make push notifications work — that still
requires a real Firebase project, a real `google-services.json`, and the
`GOOGLE_SERVICES_JSON` secret to actually be set on the repository. Until
then, every build (local or CI) will continue to run with Firebase
Messaging disabled, matching current behavior — the difference is that
this is now an explicit, visible warning instead of a silent, recurring
Sentry report with no actionable trail.

---

## Known gaps (explicitly not yet implemented)

Listed here rather than silently omitted, per the project's own
"documentation integrity" rule — nothing below should be assumed done
just because this file exists:

- **Android deploy pipeline** — `android/fastlane/{Appfile,Fastfile}` and
  `.github/workflows/deploy.yml`'s `deploy_android` job now exist and are
  wired to real secrets (see CI-001 above), but **no CI run has ever
  succeeded**, because the underlying secrets (`ENV_PROD`,
  `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
  `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `PLAY_STORE_JSON_KEY`) do
  not exist in the repo yet, and the Fastfile itself was written without
  a Ruby/fastlane environment available to run or even syntax-check it —
  see the "UNVERIFIED" comment at the top of that file. The first real
  `workflow_dispatch` run against real secrets is the actual verification
  step here, not this document.
- **Firebase / push notifications (FB-001)** — `GOOGLE_SERVICES_JSON` does
  not exist as a repo secret yet, and no Firebase Android app has been
  confirmed to exist for `com.eduzone.learn.app`. Every build today
  (local, CI quality checks, and any `deploy_android` run) has the
  `google-services` Gradle plugin skipped and ships with push
  notifications disabled — this is a silent-but-safe degradation
  (`FcmService` already handles it without crashing), not a build
  failure, so it will not show up as a red CI run. See "FB-001" above for
  the fix and how to actually enable push notifications.
- **iOS deploy pipeline** — `ios/fastlane/{Appfile,Fastfile}` exist
  (same unverified caveat as above) but `deploy.yml`'s `deploy_ios` job
  deliberately stops at the secrets-check step and does **not** attempt a
  build/archive/export, because doing so would require this repo to also
  have real Apple signing certificates and provisioning-profile handling,
  which it has never had — see `SECURITY.md`, "What's explicitly NOT
  verified here". Someone with an actual Apple Developer account needs to
  set that up before the fastlane `beta` lane has anything to upload.
- **iOS signing/provisioning documentation** — not covered here yet, for
  the same reason as above.
