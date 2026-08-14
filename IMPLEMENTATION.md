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
- **If absent:** the `release` build type silently falls back to the
  Android **debug** keystore, and Gradle prints a loud multi-line warning
  to the build log so this is never mistaken for a real release build.
  A build signed this way must never be uploaded to the Play Store or
  distributed outside the machine that built it.

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

`android/key.properties` does not exist in CI by default, so the `ci.yml`
quality job's release build always falls back to the debug-signed path
described above (safe, but not upload-ready) — that job builds for
verification, not for shipping, so this is fine as-is.

`deploy.yml`'s `deploy_android` job is the one that actually needs a real
signed build, and now writes `android/key.properties` + decodes the
keystore from CI secrets itself (`ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`),
mirroring the existing `Write .env.staging from secret` pattern in
`ci.yml`. **Status: wired but unverified** — this step only runs once all
required secrets are added to the repo (Settings → Secrets and variables
→ Actions); until then, the job posts a clear `::warning::` naming exactly
which secrets are missing and skips, rather than failing confusingly deep
inside a gradle/fastlane error. Treat CI-001 as done-but-unverified rather
than fully done until a real run has been observed to succeed.

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
