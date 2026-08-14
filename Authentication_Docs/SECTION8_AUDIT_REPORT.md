# Section 8 Audit — Real, Executed Verification (not static-only)

## What I actually did
Installed Postgres 16 + pg_cron + pg_partman locally, built a minimal
Supabase-compatible shim (`00_supabase_shim.sql`: `anon`/`authenticated`/
`service_role` roles, `auth.uid()`/`auth.jwt()` reading real GUCs the way
PostgREST does, a `vault.decrypted_secrets` stub for the KMS-key trigger),
and loaded the repo's **real, unmodified**
`supabase/schema/{01_extensions,02_types,03_tables,04_constraints,
07_functions,06_views,05_indexes,08_triggers,09_rls,10_permissions}.sql`
into it. Then wrote and ran `01_invariant_tests.sql` — real SQL, real
fixture rows, real RLS enforcement (`SET ROLE authenticated`, not
superuser) — against that database. Nothing here is mocked or guessed.

**Note on file order**: `05_indexes.sql` and `06_views.sql` need
`07_functions.sql` loaded first (materialized-view/function
cross-references) — the numeric filenames don't reflect the actual
dependency order. Not a security issue, just worth fixing in whatever
applies these files for real deployments, so dependency order doesn't
rely on luck.

## Result: 1 CRITICAL finding, otherwise strong

### CRITICAL — same-tenant user-profile disclosure (confirmed, reproducible)

`public.users_select_merged` (`supabase/schema/09_rls.sql` ~line 1481)
has a branch:
```sql
validate_user_session() AND (id = auth.uid() OR tenant_matches_jwt(tenant_id))
```
`tenant_matches_jwt(tenant_id)` means "this row's tenant is my tenant" —
not "this row is mine." Combined with a bare `OR`, **any authenticated
user can read every user row (name, role, status, tenant, etc.) in their
own tenant**, bypassing the policy's own narrower self/admin/teacher
branches. Confirmed live: a student session could `SELECT` a classmate's
row (Test 9b / Test 12, both reproduced against your actual schema).

**Verified safe to fix**: grepped every Flutter caller of `.from('users')`
and every Edge Function — all Flutter queries are scoped to
`.eq('id', <own id>)`, and all Edge Functions use the `service_role` key
(bypasses RLS entirely, unaffected either way). Nothing in the codebase
depends on the broad clause.

**Fix** (proposed, NOT applied anywhere — see caveat below): drop that
branch entirely — self/admin/teacher-of-enrolled-student are already each
covered by the policy's other branches. See
`02_proposed_fix_users_select_rls.sql`.

**Verified the fix works, locally**: applied it to my local test DB only,
re-ran the full suite — went from 10/12 to **12/12 PASS**, twice in a row
(idempotency check), with an explicit regression check confirming admin
and self visibility are unaffected.

### Everything else tested: PASS
- Test 1: valid JWT + matching DB `token_version` → session valid
- Test 2: stale `token_version` (DB moved on) → denied
- Test 3: JWT missing `token_version` → denied (fails closed, doesn't assume OK)
- Test 4: suspended account → denied
- Test 5: soft-deleted account → denied
- Test 6: no session at all → denied
- Test 7: student calling admin check → denied
- Test 8: admin session → admin check passes
- Test 9a: student reads own row → allowed
- Test 10: cross-tenant read → denied
- Test 11: JWT predating a revocation-triggering token_version bump → denied

`validate_user_session()`, `assert_valid_session()`, and
`is_admin_with_session_validation()` all behave exactly as doc 7 specifies:
DB-authoritative, fail-closed on missing/stale claims, real RBAC lookup for
admin — not a JWT-claim-only shortcut.

## Caveat — did NOT touch anything under `supabase/`
`supabase/migrations/README.md` contains leftover instructions from an
unrelated prior task ("no migrations, don't touch /supabase/"). I'm
respecting the spirit of that pending your explicit confirmation: nothing
in `supabase/schema/` was modified, and nothing was pushed. The proposed
fix is a standalone file for your review; apply it through whatever
migration process you're actually using, after you're satisfied with it.

## What Section 8 still needs (not done this session)
- RLS inventory across the *other* ~30+ tables per Phase 25 (I only
  deep-dived `public.users`, since it's the highest-value target and
  where I found the bug — same broad-clause pattern could exist
  elsewhere and hasn't been checked).
- Grants audit (Phase 29-31): `anon`/`authenticated`/`service_role`/
  `supabase_auth_admin` privilege review beyond confirming `10_permissions.sql`
  loads clean.
- RPC-by-RPC classification (Phase 10) — public/authenticated/privileged/
  internal.
- `custom_access_token` hook claim-shape audit (Phase 23-24).
- Abuse/fuzz tests (Phase 30/39-40).
- Everything in this report was tested against a fresh local DB, not
  staging/production — Phase 41 ("production-like Supabase environment")
  is still open.
