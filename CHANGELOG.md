# سجل التغييرات (Changelog)

جميع التغييرات المهمة في هذا المشروع تُوثَّق هنا.

الصيغة مبنية على [Keep a Changelog](https://keepachangelog.com/ar/1.0.0/)،
والمشروع يتّبع [Semantic Versioning](https://semver.org/lang/ar/).

## [Unreleased]

### Added / Fixed
- **Reliability (Section 13 — Networking Reliability)**: audited every
  Supabase Postgrest/RPC/Auth/Edge-Function call site against the
  established `NetworkConfig`/`NetworkGuard`/`NetworkExceptionMapper`
  pattern (already applied correctly to `courses`, `home`,
  `notifications`, `profile`, and `todo`) and found it missing entirely
  from the two most security/UX-critical paths, plus several
  fire-and-forget telemetry calls:
  - **Critical — app-startup blocker.** `UpdateRemoteDataSource
    .fetchConfig()` (`lib/features/auth/data/datasources/update_remote_ds.dart`)
    runs as the first network call of `Auth._initializeSession()` on
    every cold start and had zero timeout. `UpdateService.checkForUpdate()`
    documents itself as "never throws / fail-safe", but that only
    protects against a *thrown* error — a *stalled* connection never
    throws, so the try/catch never engaged and the app could hang on the
    splash screen indefinitely on a degraded network. Routed through
    `NetworkGuard.read`.
  - **`AuthRemoteDataSource`** (`lib/features/auth/data/datasources/auth_remote_ds.dart`):
    all 9 methods, including `login()`, had no client-side timeout at
    all — a stalled connection during sign-in hung the login button
    forever with no failure ever reaching the UI. Fixed per-method,
    choosing bound-with-no-retry (`login`, `bindDevice`, `logout`,
    `recordSession`, `_recordCurrentUserActivity`) vs. bound-with-retry
    (`checkUserAccess`, `getCurrentUser`, `validateDeviceExists`) based
    on whether the call is a pure idempotent read or has server-side
    side effects, per the project's explicit rule against blindly
    retrying auth operations. `login()` specifically uses direct
    per-await timeouts rather than a single wrapping `NetworkGuard`
    budget, so that the trailing best-effort activity-telemetry call
    can't cause an already-successful sign-in to be reported to the user
    as a timeout failure.
  - **`DownloadRemoteDataSource`** (`lib/features/downloads/data/datasources/download_remote_ds.dart`):
    zero timeout coverage, including `authorizeOfflineDownload()` and
    `revalidateOfflineEntitlement()` — the P6 offline-entitlement gate
    that decides whether a download or offline playback is allowed at
    all. `getVideoInfo()` in this file was invoking the same `video-info`
    Edge Function as `Player4RemoteDataSource.getVideoInfo()`, which
    already had the correct `NetworkGuard.read(timeout: heavyTimeout)`
    fix applied — the fix is now applied consistently to both call
    sites.
  - **Five unbounded best-effort telemetry calls**, relying only on
    `catch(_)` (which doesn't protect against a hang, only a thrown
    error): `VideoPlayerRemoteDataSource.logActivity`,
    `FcmService._saveToken`, and the near-identical
    `_logLessonStarted()`/`_logLessonStartedOnce()` in all four video
    player wrappers (modern, player4, proxy, youtube). Added a new
    `NetworkConfig.telemetryTimeout` (8s — deliberately shorter than
    `readTimeout`, since a swallowed-on-failure call should fail fast
    rather than hold a connection/battery as long as a call something
    actually depends on) and applied it to all five.
  - **Documented, not fixed — residual gap**: `RequestCancellationManager`
    (`lib/core/network/request_cancellation_manager.dart`) is wired into
    logout but its `CancelToken` is structurally inert for the vast
    majority of the app's network traffic, because Supabase's client
    runs on `package:http`, not Dio — this token can never actually
    cancel a Postgrest/RPC/Auth request (it would only affect a raw Dio
    call, and no call site in the app currently attaches it to one).
    Fixing this properly would require swapping Supabase's transport
    layer, which is a materially larger, riskier change than a Section
    13 timeout-hardening pass; flagged honestly here rather than
    papered over.
- **Security/Observability (Section 15 — Logging and Observability)**:
  audited the entire client logging/observability pipeline and fixed four
  genuine gaps:
  - **Critical — the client observability pipeline was completely
    non-functional.** `LogRemoteDataSource.syncBatch()`
    (`lib/core/logging/data/log_remote_ds.dart`) called
    `.from('activity_log_queue').insert(rows)` directly, but
    `public.activity_log_queue` has `REVOKE ALL ... FROM anon,
    authenticated` (`10_permissions.sql`) plus a
    `FOR ALL TO public USING (false)` deny-all RLS policy
    (`09_rls.sql`, "CRIT-05: Deny all PostgREST access to internal
    tables"). Every flush from every client, forever, failed with a
    permission error — meaning no activity or audit telemetry ever
    reached the backend. Rewired the client to call the existing
    `public.log_activity_async(p_user_id, p_type, p_details, p_ip,
    p_device_id, p_risk_level, p_tenant_id)` RPC (SECURITY DEFINER,
    validates `p_user_id = auth.uid()` server-side) instead, one call
    per queued entry. Neither that RPC nor `public.log_my_activity`
    had an explicit grant and were silently relying on PostgreSQL's
    implicit EXECUTE-TO-PUBLIC default instead of this project's
    explicit least-privilege model (`10_permissions.sql`) — added
    explicit `REVOKE ALL ... FROM PUBLIC, anon, authenticated` +
    `GRANT EXECUTE ... TO authenticated, service_role` for both, and a
    new `VALIDATION.sql` Check 32 that guards this end-to-end (table
    stays unreachable directly; both RPCs stay authenticated-only).
    Known residual gap: `log_activity_async` requires
    `p_user_id = auth.uid()`, so pre-login/anonymous events (e.g. an
    `AppOpenedEvent` fired before sign-in) will still fail server-side
    — same as every other event did before this fix, so not a
    regression, but not yet solved either; flagged honestly rather
    than silently claimed complete.
  - **Fail-open plaintext leak in `AuditHandler`**
    (`lib/core/logging/handlers/audit_handler.dart`): when AES-GCM
    encryption of an auth/high-risk event's `details` failed, the old
    fallback shipped `LogEntry.fromEvent(event)` — i.e. the actual
    plaintext sensitive payload (access-denial reasons, device-bind
    IDs, offline-playback-denial reasons) — to Supabase, defeating the
    entire reason this handler exists. Now fails closed: on encryption
    failure it ships a redacted placeholder (`_redacted: true`) instead,
    keeping the event's type/category/risk/ids observable without ever
    leaking the sensitive content in the clear.
  - **Malformed Sentry reporting in `CrashHandler`**
    (`lib/core/logging/handlers/crash_handler.dart`): called
    `Sentry.captureException(event.errorMessage, stackTrace:
    event.stackTrace)` with a `String` in both the "throwable" and
    "stackTrace" slots (never a real `Throwable`/`StackTrace`),
    corrupting Sentry's grouping/fingerprinting and duplicating the
    real exception `GlobalErrorHandler.logError()` already reports
    separately. Switched to `Sentry.captureMessage(event.errorMessage,
    level: SentryLevel.error)`, the correct API for a diagnostic
    string.
  - **Raw exception/stack-trace leakage to production device logs in
    `GlobalErrorHandler.logError()`**
    (`lib/shared/utils/global_error_handler.dart`): this is the single
    funnel for every uncaught Flutter/platform error, and it printed
    the full error object + stack trace via `debugPrint`
    unconditionally — including in release builds, since Flutter's
    `debugPrint` is not debug-gated. Caught errors can embed backend
    internals or request URLs with signed-URL tokens in their message.
    Now gated behind `kDebugMode`; release builds print only the safe
    `error.runtimeType`, matching the pattern already used elsewhere
    in this codebase (e.g. `fcm_service.dart`). Sentry (the controlled,
    scrubbed channel) still receives the full error + stack trace
    either way.
  Added `test/core/logging/infrastructure/event_dispatcher_test.dart`
  as a regression guard for handler isolation, alongside
  `test/core/logging/handlers/audit_handler_test.dart` and
  `crash_handler_test.dart` (the logging module had zero prior test
  coverage) covering the fail-closed redaction behavior and breadcrumb
  handling. Not independently re-verified with `flutter analyze`/
  `flutter test`/a live Supabase instance in this session (no
  Flutter/Dart toolchain, pub.dev, or Supabase network access available
  in this environment) — statically inspected only. Sentry
  `beforeSend`/`beforeBreadcrumb` scrubbing hooks were deliberately
  **not** added: the exact `sentry_flutter: ^8.14.2` callback signature
  could not be verified without pub package access in this sandbox, and
  guessing it risked shipping code that doesn't compile — flagged as a
  follow-up requiring a live environment.
- **CI (Section 25 — CI/CD)**: added `tool/check_logging_security.py`,
  a new static guard (same regex/`check-ignore` convention as
  `check_auth_security.py`) wired into `check_all.py`, `Makefile`
  (`check-logging-security`), and `.github/workflows/ci.yml`. It
  regression-guards the four Section 15 bugs fixed above one-to-one:
  direct `.from('activity_log_queue')` access, a bare
  `LogEntry.fromEvent(event)` call with no `encryptedDetails:` in
  `audit_handler.dart`, `Sentry.captureException(event.errorMessage,
  ...)`, and any empty `catch` block reappearing under
  `lib/core/logging/`. Manually verified against this session's own
  code: PASSes on the fixed code, and — checked by temporarily
  reintroducing each of the four original bugs one at a time and
  re-running the script — correctly FAILs on every one of them.
- **Security (Section 12 — Offline entitlement RPC volume / P6.25)**:
  `authorize_offline_download` and `revalidate_offline_entitlement`
  (`supabase/schema/07_functions.sql`) previously had no bound on how many
  times an authenticated identity could invoke them. Both now call the
  existing `public.check_rate_limit()` primitive (already used by
  `video-info`) keyed on `auth.uid()`, with two new rules seeded in
  `11_seed_reference.sql`: `offline_download_authorize` (100/hour) and
  `offline_entitlement_revalidate` (60/5min — generous because
  `OfflinePolicyEngine.authorize` calls it on every offline playback
  attempt while online). This is a volume bound, not a cryptographic
  replay guard — documented honestly in `SECURITY.md`: a bare re-POST of
  an already-authorized request was already harmless before this change
  (idempotent existing-row branch, state-transition trigger blocks
  resurrecting a revoked/deleted row), so no new columns or client changes
  were needed to close the actual risk. No new schema files; both edits
  are in the existing canonical `07_functions.sql`/`11_seed_reference.sql`.
- **Security (PII encryption key fallback)**: `private.get_kms_key()`
  (`07_functions.sql`) previously fell back to a fixed string committed in
  this repository (`eduzone-dev-kms-key-32bytes-secret!`) whenever the
  `eduzone_kms_key` Supabase Vault secret wasn't provisioned — silently
  encrypting `users.email_encrypted`/`phone_encrypted` with a
  publicly-visible key in any unprovisioned environment, including a
  misconfigured production one. Now fails closed (`RAISE EXCEPTION`) with
  no fallback value in any environment. Local/CI test runs are
  unaffected — they already provision a test-only Vault secret of the
  same name via `supabase/_archived_patches/00_supabase_shim.sql`. Not
  yet independently re-verified with `flutter analyze`/`flutter test`/a
  live Supabase instance in this session (no Flutter/Dart toolchain or
  network access available in this environment) — statically inspected
  only; see `SECURITY.md` "What's verified" section.
- **Evidence Gate automation (Section 12, phase 20)**: added Check 24 to
  `supabase/schema/VALIDATION.sql` — the first automated, re-runnable
  assertion that the offline-entitlement boundary is actually wired, not
  just present in source: RLS shape on `offline_download_entitlements`
  (enabled+forced, authenticated gets SELECT-own only, no unexpected
  policy), both P6.25 rate-limit rules seeded and active, the
  `trg_offline_entitlement_transition` state-machine trigger fires
  `BEFORE UPDATE`, and `private.get_kms_key()`'s live function body no
  longer contains the removed hardcoded fallback key literal. Run this
  file (`VALIDATION.sql`) after applying schema/seed to turn today's
  static-inspection claims into a PASS/FAIL that regressions can't
  silently slip past. No new file — added to the existing canonical
  validation script.
- **Security (Offline Download — P6.16 Offline Clock Security)**:
  `OfflinePolicyEngine.authorize` previously trusted `DateTime.now()`
  directly for its offline-expiry check, with no defense against a user
  disconnecting from the network and winding the device clock backward
  before every playback attempt to defeat expiry indefinitely (T5 in the
  offline threat model). Added `OfflineClockGuard`
  (`lib/features/downloads/application/services/offline_clock_guard.dart`),
  which persists — in `flutter_secure_storage`, not SQLite — the highest
  device time this app instance has ever observed, and denies playback
  (`OfflinePlaybackDenialReason.clockRollbackSuspected`) if the current
  device time falls more than 6 hours behind that watermark. Wired into
  `OfflinePolicyEngine.authorize` immediately before the expiry check, and
  into the real playback call site
  (`offline_player_wrapper.dart`) with a real
  `FlutterSecureStorage`-backed instance. Unit tests added for both the
  new guard (`offline_clock_guard_test.dart`) and its integration into the
  policy engine (`offline_policy_engine_test.dart`). Honest boundary
  documented in `SECURITY.md` and in the class doc comments: this is a
  local, device-held heuristic, not a server-issued trusted-time
  guarantee — it does not detect a device that never advanced its clock
  while online, or one whose secure storage is itself compromised
  (root/jailbreak). Not yet independently re-verified with
  `flutter analyze`/`flutter test` in this session (no Flutter/Dart
  toolchain available in this environment) — statically inspected only.

- **Security (WebView/JS injection)**: `extractModernPlayerVideoId` (Modern
  Player, `youtube-nocookie.com` WebView) previously fell through to
  returning the raw, unrecognized `content.videoUrl` value unchanged when it
  didn't match a known YouTube URL shape. That value is interpolated
  unescaped into an executing JS context (`buildModernPlayerHtml`'s
  `videoId: "$videoId"`, and `ModernPlayerWrapper._switchVideo`'s
  `evaluateJavascript("loadVideo('$videoId')")`) — a value containing `'`,
  `"`, or `</script>` could break out of the string literal and execute
  arbitrary JS inside the player's WebView. Extraction now returns `null`
  for anything that doesn't strictly match YouTube's id shape
  (`^[A-Za-z0-9_-]{11}$` or a recognized URL pattern), and two additional
  fail-safe layers were added at the actual interpolation sites
  (`buildModernPlayerHtml`, `_switchVideo`) so a future call site that
  skips this validation degrades to an inert player instead of executing
  injected script. `shouldOverrideUrlLoading` was also changed from
  allow-by-default to deny-by-default — the WebView may now only navigate
  within its own `youtube-nocookie.com` origin; everything else is
  canceled. Regression tests added covering explicit string-literal
  breakout payloads. Not yet independently re-verified with
  `flutter analyze`/`flutter test` in this session (no Flutter/Dart
  toolchain available) — statically inspected only.
- **Security (URL handling)**: `AppConfig.buildVideoUrl` (proxy video
  player) now percent-encodes `videoId` via `Uri.encodeQueryComponent`
  before placing it in the query string, preventing a value containing
  `&`/`#`/other URL-structural characters from injecting additional query
  parameters or altering the target URL.
- **Docs**: corrected a `SECURITY.md` claim that `network_security_config.xml`
  allows cleartext traffic for `127.0.0.1`/`localhost` — the actual file has
  no such domain exception; cleartext is blocked unconditionally. The
  documented policy was less strict than the real one; no code change
  required, doc corrected to match implementation.
- **Security**: ربط `SecurityService.killAppHandler` بمسار الشاشة المقفلة (`AppRoutes.locked`) عند اكتشاف تهديد أمني.
- **L10n**: إضافة الترجمة العربية لمفتاح `searchCourses` ("ابحث عن الكورسات") في `app_ar.arb`.
- **Logging**: تقييد طباعة أحداث التنقل في `AppNavigatorObserver` على وضع التطوير فقط (`kDebugMode`).
- **Chore**: إضافة ملفات المخرجات المؤقتة لـ `.gitignore` واستبعادها من تتبع Git.

 ### Security
 - ربط معالج إنهاء التطبيق `killAppHandler` لضمان التفاعل الصحيح مع التهديدات الأمنية على iOS وأندرويد.
- **`create-user` (Edge Function)**: إصلاح ثغرة orphaned-account — إنشاء `auth.users`
  و`public.users` كانا خطوتين منفصلتين بدون rollback؛ فشل الخطوة الثانية كان
  يترك حساب auth صالح بلا profile (`ServerException('User profile not found')`
  عند تسجيل الدخول لاحقًا، بلا أي مسار تعافي). أُضيف retry محدود (3 محاولات)
  + compensating rollback (`auth.admin.deleteUser`) عند الفشل النهائي، بحيث
  تصبح العملية all-or-nothing. منشور: v18.
- **`validate-course-access` + `log-download-attempt` (Edge Functions)**: إصلاح
  فلتر `tenant_id` معطّل — كان يعتمد على `user.user_metadata.tenant_id`، وهو
  حقل غير مُعبّأ إطلاقًا في هذا النظام (الـ Auth Hook `custom_access_token`
  يحقن `tenant_id` كـ top-level JWT claim، ليس داخل `user_metadata`)، مما كان
  يرفض وصول كل مستخدم مسجّل ومشترك فعلًا لبوابة الـ download authorization.
  أُزيل الفلتر المكسور والاعتماد كليًا على عزل RLS الموثوق
  (`public.get_current_tenant_id()`)، بلا أي إضعاف أمني. منشور: v17.
- **`video-info` (Edge Function)**: كانت الدالة بلا أي مصادقة إطلاقًا (CORS
  مفتوح للجميع)، فيستطيع أي مستخدم غير مسجّل على الإنترنت استدعاءها بأي رابط
  يوتيوب واستهلاك الـ Replit API الخارجي المدفوع بلا حدود. أُضيفت بوابة
  مصادقة (`auth.getUser()`) بنفس نمط `get-lesson-content`. **لم تُغلق بعد**:
  التحقق من كون المستخدم المسجّل يملك حق فعلي على الفيديو المحدد تحديدًا
  (الدالة لا تستقبل `lesson_id`) — يحتاج تغيير API contract مستقبلًا. منشور: v20.

### Automation
- **Chore**: إضافة سير عمل GitHub Actions جديد `update-goldens.yml` لتسهيل تحديث الـ Goldens.

---

## [1.0.0+1] — نقطة البداية (Baseline)

> هذا الإصدار هو نقطة الانطلاق لهذا الـ Changelog. التغييرات السابقة لهذا
> التاريخ غير موثّقة هنا لأن تاريخ Git الفعلي للمشروع بدأ بـ commit واحد
> مجمّع ("initial project structure 2") بدون سجل تدريجي.

### Added
- بنية Clean Architecture كاملة (Feature-first) عبر الميزات: `auth`,
  `courses`, `downloads`, `video_player`, `notifications`, `profile`, `todo`.
- تشفير AES-256-GCM للفيديوهات المحمّلة (offline) مع مفاتيح فريدة لكل
  تحميل عبر `flutter_secure_storage`.
- جلسة Supabase عبر PKCE flow + Secure Storage.
- نظام Design Tokens كامل (`lib/design_system/tokens/`).
- دعم RTL (عربي أولاً) + Dark Mode + Localization (عربي/إنجليزي).
- تكامل freeRASP لكشف الأجهزة المروّطة/المحاكيات (مستند لإعدادات البيئة — راجع التوثيق في `lib/core/security/README.md`).
- CI عبر GitHub Actions: `flutter analyze`, `flutter test --coverage`, `flutter pub audit`.

### Known Issues (وقت كتابة هذا السجل)
- فحص freeRASP يتطلب تزويد المفاتيح (`SECURITY_ANDROID_SIGNING_HASH`, `SECURITY_IOS_TEAM_ID`) عبر `--dart-define-from-file=.env.security` في بناء الإنتاج.
- ~~بناء الإصدار (Release) لأندرويد موقّع بمفتاح Debug مؤقتًا بانتظار keystore إنتاج.~~
+  **محدّث (تدقيق الإنتاج):** لم يعد هذا صحيحًا. `android/app/build.gradle.kts`
+  يرفض الآن بناء أي `release` بدون `android/key.properties` صالح
+  (`GradleException: "Production release builds require android/key.properties..."`),
+  أي أن fallback إلى مفتاح Debug لم يعد ممكنًا فعليًا — تحقّق ثابت `verified`
+  من قراءة الكود، وليس افتراضًا (`assumed`). ما لم يُتحقق منه بعد فعليًا هو
+  تنفيذ بناء `release` كامل موقّع بـ keystore إنتاج حقيقي على بيئة CI/CD
+  (`blocked by environment`: لا يوجد keystore إنتاج/رنر متاح في جلسة هذا التدقيق).

- **CI — خطوة "Build APK (Staging)"**: هذه الخطوة في `.github/workflows/ci.yml` تُتخطّى عمدًا (`exit 0`) إذا لم يكن ملف `.env.staging` متوفرًا في بيئة الـ Runner، وذلك بشكل مقصود لتفادي فشل الـ CI للمساهمين الذين لا يملكون صلاحية الوصول لأسرار المشروع (Fork/Contributor PRs). **الأثر**: نجاح job الـ `quality` في CI **لا يعني** أن بناء الـ APK الفعلي (Staging) قد تم التحقق منه؛ فقط يعني نجاح `flutter analyze` و`flutter test`. للتحقق الفعلي من قابلية البناء، يجب تفعيل GitHub Secret باسم `ENV_STAGING` (محتوى ملف `.env.staging`) في إعدادات المستودع (`Settings → Secrets and variables → Actions`)، ثم تعديل الخطوة لإعادة توليد الملف من السر قبل خطوة البناء.

---

## كيف تضيف إدخالًا جديدًا

عند فتح PR يغيّر سلوكًا ملحوظًا، أضف سطرًا تحت `[Unreleased]` بالقسم المناسب:
`Added` (ميزة جديدة) / `Changed` (تعديل سلوك موجود) / `Fixed` (إصلاح خطأ) /
`Security` (إصلاح أمني) / `Removed` (إزالة ميزة). عند إصدار نسخة جديدة، انقل
محتوى `[Unreleased]` لقسم جديد بترقيم الإصدار وتاريخه، واترك `[Unreleased]`
فارغًا للتغييرات القادمة.
