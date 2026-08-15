# Security

Status: statically inspected against repository state as of commit
`960f53043ff9f19a574757a3c3ae23b8eb3c8696` — no Flutter/Dart toolchain or
device/emulator available in the environment this was written in, so
nothing here reflects a runtime-verified test, only direct source
inspection (grep/read, not execution), **except** `flutter analyze` /
`flutter test`, which the project's maintainer has since run directly —
see "What's verified — by the developer, not by this document's author"
below. See `ARCHITECTURE.md` for the layering/dependency-direction
contract; this file is security posture specifically, not architecture.

This file documents the security controls that actually exist in this
repository today, and — just as importantly — what they do *not* provide.
Per the project's own instructions, this repo avoids claiming "secure" or
"production-ready" as a blanket statement; controls are described
individually, each with what it defends against and what it doesn't.

If you're looking for the full offline-download threat model and key
lifecycle, see `EduZone_Offline_Download_Security_Trusted_Playback_Architecture.md`.
This file is the shorter, code-grounded companion referenced directly from
inline comments (`android/app/build.gradle.kts`, `.env.security.example`).

---

## Secrets and configuration

- The Flutter client only ever reads `SUPABASE_ANON_KEY` at runtime
  (verified: no reference to a service-role key anywhere under `lib/`).
  `.env.example` intentionally does **not** include
  `SUPABASE_SERVICE_ROLE_KEY` — that key belongs only in trusted
  backend/Edge Function environments, never in code shipped to a device.
- `.env*`, `*.keystore`, `*.jks`, `android/key.properties`,
  `android/play-store-key.json` (the Play Console service-account key
  `deploy.yml` writes locally from the `PLAY_STORE_JSON_KEY` secret), and
  `*.p8`/`*.p12`/`*.mobileprovision` (iOS signing material, not currently
  produced by any workflow but git-ignored defensively) are git-ignored.
  `.env.example` and `.env.security.example` are templates only — see
  `.gitignore` for the exact rules.
- `tool/check_config_security.py` (wired into CI as the `Config/Secrets
  Security Guard` step, and into `make check-all`) statically enforces
  this: it fails if any of the patterns above lose `.gitignore` coverage,
  if a real `.env*` file other than the two templates is ever tracked in
  git, if a `String.fromEnvironment(...)` call gives a non-empty default
  to a secret-shaped variable name, or if a `supabase/` deploy script
  references a `.sql` file that doesn't actually exist in the repo. This
  is a heuristic static check, not a replacement for the `secret_scan`
  (gitleaks) CI job, which is the authoritative full-history secret scan.
- Session tokens (`access_token`, `refresh_token`) are stored via
  `flutter_secure_storage` (Android Keystore / iOS Keychain-backed), not
  `SharedPreferences`. See `lib/features/auth/application/services/logout_orchestrator.dart`
  for where they're wiped on logout.

## Session revocation (server-side, DB-authoritative)

`public.validate_user_session()` (`supabase/schema/07_functions.sql`) is
the single point every RLS-facing role/admin check funnels through. It
compares the JWT's `token_version` claim against the current
`token_version` stored on `public.users` — a real per-request database
lookup, not a JWT-only comparison. This matters specifically because an
earlier version of this function had a "fast path" that compared two
copies of `token_version` embedded in the *same* JWT against each other
(trivially always equal), which meant bumping `token_version` server-side
to revoke a session had no actual effect until the JWT itself expired.
That fast path has been removed; revocation is now enforced immediately
on the next request, at the cost of one row lookup per validation instead
of zero (a deliberate correctness-over-performance trade — see the
`AUTH-FIX-01` comment in `07_functions.sql` for the reasoning). The
"lite" role-check helpers (`is_current_user_admin_lite`,
`is_current_user_super_admin_lite`) previously trusted `primary_role` /
`is_admin` claims straight from the JWT with no revocation check at all;
they now delegate to the full DB-backed functions, closing the same gap
for admin-privilege checks specifically.

## Error observability in `lib/features/auth` is intentionally NOT uniform

37 `debugPrint(...)` calls exist across `lib/features/auth` (as of this
commit). They are **not** uniformly wired to Sentry, and that's a
deliberate classification, not an oversight:

- **Routed to `GlobalErrorHandler.logError()` (→ Sentry) — 10 sites**:
  every unexpected failure in `auth_provider.dart` (device re-bind,
  non-transient session-init/verify-access/refresh-user failures),
  `check_user_access_service.dart`'s background security-check loop, and
  all 4 steps of `logout_orchestrator.dart` (server revocation, local
  Supabase sign-out, secure-storage wipe, SharedPreferences wipe). These
  share two properties: they're triggered by app/system logic, not
  directly by user input, and a failure means something genuinely
  didn't work as intended (most sharply for the logout steps — a failed
  wipe there means tokens or a session may still be live on the device
  after the user believes they've logged out).
- **Left as `debugPrint`-only, deliberately not sent to Sentry**:
  everything else, including `login()`'s own failure branch. Reading
  that branch matters here: it fires on *every* non-transient login
  failure, which includes an ordinary wrong password — routing that to
  Sentry would flood crash reporting with normal user behavior on every
  wrong-password attempt, burying real signal in noise. The same
  reasoning applies to transient-error branches (network blips, not
  bugs) and anything already explicitly commented `(non-critical)` in
  the source (offline-download purge on login, background activity
  sync, the in-app update check).

If you're auditing this list yourself, the question that matters per
call site is "does this represent a bug/security event, or a normal
outcome of something a real user does routinely" — not "is this inside
a catch block."

## Transient network errors never force a logout

`AuthState` has a dedicated `AuthDegraded` variant
(`lib/features/auth/domain/entities/auth_state.dart`): when a local
Supabase session exists but the app can't reach the server to verify it
(timeout, DNS failure, no connectivity, 5xx — anything
`AuthErrorPolicy.isTransient()` classifies as transient), the session is
left completely untouched — no local cleanup, no server-side sign-out
call, no redirect to `/login`. The router keeps the user on `/splash`
while `Auth` retries automatically with capped exponential backoff (2s,
4s, 8s, 16s, 32s; 5 attempts max — `_scheduleDegradedRetry` in
`auth_provider.dart`), and stops auto-retrying past the cap rather than
retry-storming indefinitely. This exists specifically because the
opposite used to be true: any transient error hit during cold-start
session verification fell straight through to `AuthUnauthenticated`,
which the router maps directly to `/login` — silently discarding a valid
session over a network blip. An **explicit** denial from the server
(banned/suspended/locked/maintenance) is never affected by this and still
redirects immediately, regardless of the transient-error path above.

## Network security

- Android: `usesCleartextTraffic="false"` in `AndroidManifest.xml`, with
  `network_security_config.xml` allowing cleartext **only** for
  `127.0.0.1` / `localhost` (local dev tooling), nothing else.
- iOS: no `NSAllowsArbitraryLoads` or other ATS exceptions in
  `Info.plist` — default (secure) App Transport Security applies.
- Certificate pinning: `lib/core/network/certificate_pinning.dart` pins
  against the certs in `assets/certs/` (`supabase.pem`, `supabase_leaf.pem`,
  `backup_ca.pem`) for Supabase-hosted requests specifically (see
  `isSupabaseHost()` in that file for exactly which hosts are covered).
  Traffic to other hosts (e.g. the video proxy, see `PROXY_BASE_URL`) is
  **not** pinned.

## Device integrity (freeRASP)

Configured in `lib/core/security/freerasp_config.dart`. Detects
root/jailbreak, hooking frameworks, and app tampering/repackaging (via
`SECURITY_ANDROID_SIGNING_HASH` / `SECURITY_IOS_TEAM_ID`, both required at
release build time — see `IMPLEMENTATION.md`, REL-001).

**Default posture is log-only, not enforcing:**
`SECURITY_ENFORCE_THREAT_TERMINATION` defaults to `false`
(`.env.security.example`). Threats are reported to a Supabase
`security_incidents` table (fire-and-forget insert with a device
fingerprint, app version, and platform info — see `_logThreatToSupabase`
in `lib/core/security/security_service.dart`), with a capped in-memory
fallback buffer if the insert can't complete (e.g. offline, or Supabase
not initialized yet at startup). This is a separate path from the
Sentry/`CrashHandler` event pipeline described above — freeRASP threats do
**not** currently go through Sentry. The app is **not** terminated on
detection until `SECURITY_ENFORCE_THREAT_TERMINATION` is deliberately
flipped to `true` for a release, after confirming an acceptably low
false-positive rate against the `security_incidents` data. Until that
flip happens, treat root/jailbreak/tamper detection as telemetry, not
enforcement.

## Offline downloads

AES-256-GCM, one randomly generated 256-bit key per download (verified in
`lib/core/services/encryption_service.dart`), 512 KiB chunked encryption,
SHA-256 integrity hashing. Keys live in `flutter_secure_storage`, never in
SQLite alongside the download metadata.

Cleanup (`lib/core/services/cleanup_scheduler.dart`) deletes the
encrypted file, then the key, then the DB row, in that order — if key
deletion fails, the DB row is deliberately **not** deleted, so the next
cleanup cycle retries that item instead of leaving an untracked orphaned
key. `OfflineAccountGuard.purgeDownloadsForOtherAccounts` (called right
after login) follows the identical fail-safe order for the same reason.

Playback authorization is centralized in `OfflinePolicyEngine.authorize`
(`lib/features/downloads/application/services/offline_policy_engine.dart`)
— every offline playback attempt re-reads the download's status, expiry,
account/device binding, file presence, and key presence from local storage
at the moment of play (not a cached in-memory value), and denies playback
if any check fails. Account/device binding (`user_id`/`device_id` columns,
schema v7) means a second account signing in on the same device neither
sees nor can play back a previous account's downloads — enforced at three
independent points: the downloads list query, the playback-time policy
check, and an active purge on login. Downloads created before this binding
existed (`user_id`/`device_id` both `NULL`) are adopted by whichever
account plays them first rather than retroactively invalidated — a
deliberate one-time migration trade-off, not an ongoing gap for anything
downloaded from this point on.

`OfflineCrashRecovery` (called once at startup) reclassifies any download
stuck in `pending`/`downloading` status to `failed`, since nothing in this
codebase auto-resumes a download across an app restart — a row in one of
those statuses at cold start can only mean the process that was writing
to it is gone.

Since schema v8, the security-critical fields that `OfflinePolicyEngine`
actually bases its decision on (`id`, `user_id`, `device_id`, `expires_at`,
`download_status`) are HMAC-SHA256 signed on every write
(`StorageService._sign`/`_signAfterMerge`, applied inside
`insertDownload`/`updateDownloadStatus`/`updateDownload` — the only three
write paths every caller in this codebase funnels through) with a key that
lives only in `flutter_secure_storage`, never in SQLite next to the data
it protects. `OfflinePolicyEngine.authorize` re-verifies this signature
(`StorageService.verifyDownloadSignature`) before trusting any of those
fields — a row edited directly in the SQLite file (e.g. via a SQLite
browser on a rooted device, bypassing this app's own code entirely) no
longer matches its signature and is denied as
`OfflinePlaybackDenialReason.tampered`, regardless of what the edited
field values say. Rows created before this signing existed
(`security_signature IS NULL`) are treated as "not yet signed" rather than
denied, and get a real signature automatically the next time anything
legitimately updates them — the same one-time migration trade-off as the
v7 account/device binding above.

This closes the gap where a security decision depended purely on local
metadata a user could edit directly — but the HMAC key is
device-generated and device-held, not server-issued: it raises the bar
against casual local tampering, not against an attacker who has fully
compromised the device and can extract the key itself alongside
everything else. That remains a real, deliberately-documented limitation
below.

**What this is not:** client-side AES-GCM encryption is not equivalent to
hardware-backed DRM (Widevine L1 / FairPlay). It raises the bar against a
casual user copying files off the device; it does not defend against a
sufficiently motivated attacker with root/jailbreak access extracting keys
from a compromised device at the moment of use. Likewise, the
`security_signature` HMAC above raises the bar against direct database
edits but is not a server-issued, cryptographically signed license — there
is no backend entitlement/license-issuance endpoint in this repo (see
`EduZone_Offline_Download_Security_Trusted_Playback_Architecture.md`
P6.3/P6.4), and no anti-replay protection (P6.25). See the offline-security
architecture doc for the full threat model this is explicitly scoped
against (and not against).

## What's verified — by the developer, not by this document's author

This document was originally written entirely by static source inspection
(no Flutter/Dart toolchain was available to the session that wrote it).
Two items below have since been closed by the project's own maintainer,
running the real toolchain directly — recorded here as developer-reported
results, not independently re-verified by re-running them:

- `flutter analyze`: **0 issues** (developer-reported).
- `flutter test`: **845 tests passed**, 0 failures (developer-reported).

This closes the largest verification gap that existed across this whole
audit — up to this point, every fix in this file had only ever been
checked against the project's own Python static guards (`tool/check_*.py`,
all passing), never against the actual Dart analyzer or test suite. Static
guards catch pattern-level issues (architecture layering, provider
lifecycle, a11y semantics, RTL, memory-hygiene, auth-security patterns);
they cannot catch a genuine compile error, a broken test assertion, or
the kind of runtime behavior only `flutter test`/`flutter analyze`
actually exercise. Both gaps are now closed.

## What's explicitly NOT verified here

Per the project's own "No Fake Completion" rule — these have not been
exercised in a real build/release environment as of this document:

- A real Android release build signed with a production keystore (only
  the debug-keystore fallback path has been exercised locally).
- Any iOS release/archive build or provisioning profile.
- CI-side release signing (`key.properties` is not currently written from
  CI secrets — see `IMPLEMENTATION.md`, CI-001).
- Store submission via `deploy.yml` (Android is wired to real secrets
  now but has never had a successful CI run; iOS deliberately stops
  short of a build/archive step — see `IMPLEMENTATION.md`, "Known
  gaps").
- Row Level Security (RLS) policy correctness on the Supabase backend —
  this repo is the Flutter client only; RLS lives in the backend project
  and must be audited there, not assumed correct from the client side.

Report a security issue by opening a private security advisory on this
repository (GitHub → Security → Advisories), not a public issue.
