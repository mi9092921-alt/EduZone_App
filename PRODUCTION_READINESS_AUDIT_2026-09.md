# EduZone Production Readiness Audit — 2026-09-13

> **Addendum (same day, CI bring-up session):** the first real CI executions surfaced
> and closed five more defects. (1) `subosito/flutter-action@v2` could not resolve the
> pubspec flutter RANGE → every flutter job died at setup; fixed by pinning
> `flutter-version: 3.44.8` in all workflows (`bab172e`). (2) The strict architecture
> guard contradicted AGENTS.md's documented auth-providers exception (`3813805`).
> (3) Real-device integration run (Oppo CPH2269, API 30) exposed: WCAG contrast
> failures on the login subtitle (3.76:1) and version footer (1.56:1), an unlabeled
> agree-to-terms Checkbox, an unnamed full-screen tap node, and an AR
> title/button string collision ("تسجيل الدخول" ×2) — all fixed (`82a1d87`), button
> now "دخول". (4) The integration test leaked its SemanticsHandle (addTearDown runs
> after the end-of-test verification) — fixed with explicit dispose (`333abb7`).
> (5) `todo_date_formatter_test` needed `initializeDateFormatting('en')` (unit tests
> lack MaterialApp's intl bootstrap) — fixed (`333abb7`). CI `integration_test` runs
> without KVM (TCG, `-accel off`): locally observed 13m boot + 8m Gradle + 8m install,
> tests ~10× slower; job now bounded at 4h (`d539938`). Local verification at close:
> `flutter analyze` clean, **1169/1169 unit**, **10/10 integration on hardware**.

**Scope:** Student App (`EduZone_App` @ `6b626ea`, 1 unpushed sync commit), Shared Supabase
(canonical: `EduZone_dashboard` @ `98cc1d3`), Dashboard (`EduZone_dashboard` main).
**Method:** full re-verification from current state only — no prior report was trusted.
Every VERIFIED claim below carries its evidence; everything else is explicitly
UNVERIFIED. Live production DB was probed **read-only** (SELECT on system catalogs).
All RLS tests ran against the **TEST project** inside transactions that were rolled back
(zero residue).

---

## 1. What was verified (with evidence)

| # | Claim | Evidence |
|---|---|---|
| V1 | Student app: `flutter analyze` → **No issues found** | local run 2026-09-13 |
| V2 | Student app: `flutter test` → **1165/1165 passed** (incl. 6 new) | local run 2026-09-13 |
| V3 | Student app: **release APK builds** (`app-release.apk`, 89.1 MB, `.env.prod`) | `flutter build apk --release` exit 0 |
| V4 | Prod DB has `check_student_app_access()` — SECURITY DEFINER, `search_path=public,pg_temp`, granted to `authenticated` | `pg_proc` probe (read-only) on `db_url.txt` project |
| V5 | Prod Realtime publication `supabase_realtime` includes `public.users` + `public.user_notifications` | `pg_publication_tables` probe |
| V6 | All SECURITY DEFINER functions on prod set explicit `search_path` | `pg_proc.proconfig` probe |
| V7 | **RLS 12/12** on TEST project: own-rows positive ×2; cross-student deny (todos/notifications/devices/entitlements); forged `tenant_id` claim does not widen visibility; stale `token_version` → total blackout; anon denied (incl. no direct grants); forged-ownership INSERT rejected (WITH CHECK); cross-tenant courses isolation | `_audit/rls_tests.js` — all scenarios SELECT-only or rolled back |
| V8 | Schema trees unified: app's nested `supabase/schema` ≡ dashboard repo `supabase/schema` (13/13 files, README wording aside) | `diff -rq` |
| V9 | Dashboard: `pnpm install --frozen-lockfile` ✓, typecheck 4/4 ✓, lint 4/4 ✓, **tests 1176/1176** ✓, **production build ✓** (env provided exactly as CI does: placeholders with `vars` fallbacks) | local runs 2026-09-13 |
| V10 | Secret hygiene: `supabase/db_url.test.txt` untracked; removed from the only commit that ever contained it (unpushed, amended → never enters history); `.gitignore` rule committed | `git ls-files`, `git show --stat HEAD` |
| V11 | Git history of BOTH repos contains **no real secret values** (pattern scan for `eyJ…`/`sbp_`/`SERVICE_ROLE_KEY=` across all history; only prose mentions + test placeholder) | `git log --all -S` |
| V12 | Cert pinning: pinned certs are WE1 intermediate (exp **2029-02-20**) + GlobalSign Root (exp **2028-01-28**); wired into `supabase_client.dart` + `download_manager.dart`; `withTrustedRoots:false` | openssl + code read |
| V13 | `supabase_leaf.pem` (exp **2026-09-26**) is **not referenced anywhere** (dead asset, not pinned) | grep of lib/ + pubspec |
| V14 | CI `quality` job's canonical-schema validation matches the current tree layout | workflow read |
| V15 | Signing/secret files NOT tracked: `key.properties`, `release.keystore`, `google-services.json`, `.env*` (except `*.example`) | `git ls-files` |
| V16 | Seed QA accounts: **0 rows on prod** carry the committed bcrypt hash — the seed backdoor (F-01) was already fixed in `deploy.js` (QA seed is opt-in) | pg_proc/auth.users probe |

## 2. Fixed in this audit (student repo working tree)

| Fix | Files | Verification |
|---|---|---|
| Secret file untracked + amended out of unpushed sync commit + gitignore rule committed | `6b626ea` (amended) | V10, V11 |
| 3 player widgets called `log_activity_async` directly (violates "repositories call Supabase") → routed through `LogRemoteDataSource.logLessonStarted()` | `lib/core/logging/data/log_remote_ds.dart`, `youtube_player_wrapper.dart`, `modern_player_wrapper.dart`, `player4_wrapper.dart` | analyze 0 issues; new test `test/core/logging/data/log_remote_ds_test.dart` (6 cases incl. timeout & swallow paths); full suite 1165/1165 |
| AGENTS.md doc drift corrected to current reality (router path+routes, design_system tokens, l10n path, Riverpod 3.x, JWT secure-storage policy, supabase mirror note, reference files) | `AGENTS.md` | reviewed diff |

## 3. Findings matrix (current state)

| ID | Area | Sev | Status | Evidence | Root cause | Required fix | Impl. status | Verification | Cross-repo | Launch impact |
|---|---|---|---|---|---|---|---|---|---|---|
| F-01 | Secrets | P0 | FIXED | db_url.test.txt tracked w/ live creds; never pushed | sync commit force-added ignored file | untrack + amend + ignore | **DONE (6b626ea)** | git ls-files empty | dashboard repo clean | unblocks push |
| F-02 | DB deployment drift | P0 | OPEN (external action) | prod `pg_proc` missing `admin_get_job_counts_tenant`, `admin_get_job_tenant_id`; anon EXECUTE on `control_user_account`, `get_users_paginated`, `soft_delete_user`, `increment_warning_count`, `get_tenants_usage` | prod DB older than canonical `10_permissions.sql` (which revokes anon: :470-471, :573-580) | deploy canonical schema from dashboard repo (`node deploy.js`) in a maintenance window | NOT run — shared prod DB change requires owner approval | re-run `_audit/db_readonly_probe*.js` after deploy | Dashboard Jobs/Tenants pages break on current prod DB | **blocks release** |
| F-03 | Prod accounts | P0 | OPEN (external action) | 6 qa/test accounts on prod auth.users, active, confirmed, passwords ≠ seed hash; super_admin last sign-in Sep 1, admin+teacher Sep 11 | historical QA seeding into prod | delete or lock the 6 accounts (+ any data they touched); QA only on TEST project | SQL prepared in report §6 | post-cleanup probe | — | **blocks release** |
| F-04 | Schema governance | P1 | OPEN | prod tables `v_key`,`v_url` (columns: `decrypted_secret text`) — no RLS, not in canonical schema, only postgres+service_role grants | legacy video-key cache predating schema governance | migrate value to Vault or drop; never restore plaintext key tables | documented | probe3 | — | hardening, not exposed via API |
| F-05 | Prod auth config | P1 | OPEN | config.toml: min password 6, no password requirements, email confirmation off, site_url localhost | dev defaults in shared config | set production password policy/confirmations in Supabase Auth settings; site_url → dashboard domain | documented | Supabase dashboard | dashboard | blocks "production" claim |
| F-06 | RPC naming | P2 | CLOSED | `check_user_access` no longer defined OR called anywhere in current code/schema; replaced by `check_student_app_access()` / `check_dashboard_access()` | earlier rename completed | none | verified in canonical 07_functions.sql:7007+ | V4, dashboard grep | both apps aligned | none |
| F-07 | Offline licensing | P2 | ACCEPTED | download keys are device-generated (HMAC, secure storage); documented "not DRM" | design decision | optional server-signed licenses post-launch | documented in code | code read | — | accepted risk |
| F-08 | Layering | P3 | PARTIAL | 3 app-layer services call Supabase directly (logout_orchestrator, check_student_app_access_service, security_service) | orchestration services predate rule | optional RFC + move to repositories | documented (accepted: services, not widgets) | code read | — | none |
| F-09 | Dead asset | P3 | OPEN | `assets/certs/supabase_leaf.pem` expires 2026-09-26, unreferenced | leftover from earlier pinning strategy | delete file (or rotate into pins if ever used) | pending | grep V13 | — | none |
| F-10 | Dependencies | P3 | OPEN | ~30 packages outdated (riverpod 3.3.1→3.4.3, secure_storage 10→11, go_router 17→18, freerasp 8.0→8.2.2) | routine lag | scheduled upgrade PRs (dependabot exists) | documented | `flutter pub outdated` | — | none |
| F-11 | CI flake | P3 | OPEN | first `turbo test` run failed, immediate re-run passed 1176/1176 | resource contention / vitest worker | watch CI; consider `--pool=forks` if recurs | documented | local ×2 runs | dashboard CI | none |

## 4. Status tables

### Launch Blockers (remaining)
| ID | What | Owner action |
|---|---|---|
| F-02 | Deploy canonical schema to prod | run `supabase/deploy.js` (dashboard repo) in maintenance window |
| F-03 | Remove/lock 6 prod QA accounts | run §6 SQL |
| F-05 | Prod auth settings hardening | Supabase dashboard |
| — | First green CI run after push (gitleaks/OSV/emulator) | push branch, watch Actions |

### Security Findings
F-01 (fixed), F-02 anon grants (open, deploy), F-03 QA accounts (open), F-04 (open),
F-12 UNVERIFIED: service_role/sbp_ **rotation** — files never reached any remote
(history-clean, V11), rotation still recommended as defense-in-depth. Requires
Supabase dashboard access (external).

### Authorization / RLS Findings
RLS tenant isolation **VERIFIED by negative testing** (V7) on TEST project.
UNVERIFIED: identical re-run on prod post-deploy (script ready; needs session-claim
replay which is read-only but touches prod, so left for the owner).

### Functional / Reliability / Performance / CI-CD / Dependencies / Configuration / Testing Gaps
- Functional: course/enrollment/download/video paths covered by 1165 unit+widget tests;
  E2E on emulator = **UNVERIFIED locally** (CI job `integration_test` covers on push).
- Reliability: NetworkGuard timeouts + auth error policy verified by tests; logout
  orchestrator wipes FCM token, realtime channels, secure storage (code + tests).
- Performance: release build minified+shrunk (345.9s, 89.1 MB); no perf gate run
  (`tool/download_benchmark.dart` available) — UNVERIFIED this round.
- CI/CD: student CI quality/secret-scan/OSV/integration/golden jobs validated against
  current tree layout; dashboard CI env-fallback verified; deploy.yml requires secrets
  (external).
- Dependencies: F-10. Configuration: F-05. Testing gaps: no dedicated
  `LogRemoteDataSource` test existed → added; per-file coverage rule otherwise met.

## 5. Answers to the mandatory questions

1. **الحالة الفعلية:** التطبيق جاهز هندسيًا وقابل للإثبات: analyze نظيف، 1165 اختبارًا
   ناجحًا، release APK يُبنى، RLS مختبرة سلبًا وإيجابًا، الأسرار المؤقتة أُزيلت. ما يمنع
   "جاهز" القاطع هو حالة **القاعدة الحية** لا الكود.
2. **ما يمنع الإطلاق الآن:** F-02 (دريف نشر القاعدة الحية — صفحة Jobs في الـ Dashboard
   مكسورة على prod فعليًا + منح anon على دوال إدارية)، F-03 (حسابات QA نشطة على prod
   بينها super_admin)، F-05 (إعدادات auth ضعيفة).
3. **الثغرات:** المنح الأعم من canonical على prod (تُغلق بالنشر)، جدولا v_key/v_url
   غير المُدارة، مفتاح service_role غير مدوَّر (لم يُسرَّب أبدًا — تاريخ نظيف).
4. **الأخطاء:** 3 widgets كانت تستدعي Supabase مباشرة (أُصلحت)، flake عابر في turbo test،
   drift لا أكثر — لا أخطاء منطقية جديدة عُثر عليها في 1165 اختبارًا.
5. **ما أُصلح:** F-01 كاملًا، طبقة الـ player widgets + اختبارها (6 حالات)، AGENTS.md.
6. **ما تم التحقق منه فعليًا:** جدول §1 (V1–V16).
7. **UNVERIFIED:** تدوير الأسرار (يتطلب dashboard)، RLS re-run على prod بعد النشر،
   integration tests محليًا (CI يغطيها)، Play deployment، E2E للـ dashboard.
8. **تأثير القاعدة المشتركة:** canonical = dashboard repo؛ شجرة التطبيق مرآة متزامنة
   (مثبتة بالـ diff)؛ أي تغيير DB يجب أن يمر من dashboard repo ثم يُزامَن.
9. **الترتيب المطلوب:** نشر schema → تنظيف حسابات QA → تدوير مفاتيح → hardening auth →
   push + CI أخضر → إعادة RLS probe → إطلاق.
10. **Go/No-Go:** انظر أدناه.
11. **الدليل النهائي المطلوب:** V1–V16 + إغلاق F-02/F-03/F-05 + CI أخضر على main + probe
    نظيف بعد النشر.

## 6. SQL for owner execution (F-03 + F-02 verification)

```sql
-- F-03: audit then lock (do NOT hard-delete before backup)
SELECT a.email, u.primary_role, u.account_status, a.last_sign_in_at
FROM auth.users a LEFT JOIN public.users u ON u.id = a.id
WHERE a.email LIKE '%eduzone-test.com%' OR a.email LIKE '%eduzone.local%';
-- then: ban/delete via Supabase Auth admin (GoTrue) + soft-delete public.users rows
```
Re-verify after schema deploy: `_audit/db_readonly_probe.js` + `db_readonly_probe2.js`
(missing-functions list must become empty; anon grants gone).

## 7. FINAL STATUS

**GO WITH EXPLICIT CONDITIONS** — student-app code, tests, build, RLS negative-testing,
and secret hygiene all pass with evidence (§1); release is conditioned on the owner
executing F-02 (schema deploy), F-03 (QA account cleanup), F-05 (auth hardening),
key rotation (recommended), and one green CI run after push. None of these are code
changes in this repository.
