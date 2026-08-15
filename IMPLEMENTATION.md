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
