# Section 8 Audit — Authentication & Authorization Release Review

## Scope

This report reflects the uploaded repository snapshot reviewed for this pass.
The target is Section 8 of the project instructions: authentication/session
hardening plus database-enforced authorization. The review distinguishes
repository evidence from environment-dependent verification.

## Current verified findings

### Fixed in the canonical schema

1. **Tenant-wide profile disclosure** — the final `public.users` SELECT policy
   is limited to the current user, administrators, or teachers viewing students
   enrolled in one of their own courses. The earlier tenant-wide
   `tenant_matches_jwt(tenant_id)` branch is removed from the effective policy.

2. **Tenant-wide course disclosure** — the effective `public.courses` policies
   now expose published courses publicly, while authenticated access to
   non-published/non-public rows requires the current database tenant plus
   administrator/teacher/course-access/permission authorization. JWT tenant
   metadata is no longer sufficient to authorize a course row.

3. **Tenant-wide enrollment disclosure and cross-user enrollment writes** —
   enrollment SELECT/UPDATE/INSERT policies now require current database
   tenant context, and self-service mutation is limited to the authenticated
   user. Direct enrollment insertion is administrator-only; student enrollment
   continues through `enroll_in_course()` which is the app's existing RPC path.

4. **Cross-tenant user-progress mutation** — INSERT/UPDATE/DELETE policies now
   require `assert_tenant()` / `get_current_tenant_id()` in addition to the
   authenticated user/admin check. SELECT is limited to the user's own
   progress, administrators, or teachers of the corresponding course.

5. **Auth Hook permissions** — `supabase_auth_admin` is explicitly granted
   `USAGE` on `public` and `EXECUTE` on `public.custom_access_token(jsonb)`;
   `anon` and `authenticated` are explicitly denied EXECUTE.

## Authentication controls verified by source inspection

- Session revocation is DB-authoritative through `validate_user_session()` and
  `token_version`; missing/malformed JWT `token_version` fails closed.
- `is_admin_with_session_validation()` validates the session before checking
  the server-side role/RBAC state.
- The custom access-token hook rejects missing/inactive `public.users` rows
  before issuing a token and injects `tenant_id`, `primary_role`, `region_id`,
  `is_admin`, `token_version`, and `account_status` claims while leaving the
  reserved PostgREST `role` claim unchanged.
- Flutter cold-start verification preserves a local session during transient
  network failures instead of converting a network outage into a forced
  logout/navigation to `/login`.
- Device binding, session cleanup, provider invalidation, and passive auth-state
  revocation paths are present in the auth feature.
- The access-monitoring service now ignores in-flight RPC and Realtime callbacks after `stop()`, preventing a pre-logout security result from mutating post-logout auth state. A regression test covers the in-flight RPC race.
- The repository contains a dedicated auth static guard and it passes in strict
  mode (`python3 tool/check_auth_security.py --strict`).

## Verification boundary

The uploaded workspace does not contain a Git history, a running Supabase
project, or a local PostgreSQL server executable. Therefore the following were
**not** claimed as runtime-verified in this pass:

- live production/staging RLS execution against Supabase;
- real Auth Hook issuance/refresh behavior against GoTrue;
- Android/iOS runtime authentication flows;
- the project's full Flutter analyzer/test/build matrix.

`supabase/schema/VALIDATION.sql` now includes regression checks for the Auth
Hook permissions, dangerous tenant-wide policies on the sensitive tables, and
tenant binding of self-service writes. These checks are intended to be run
against the canonical schema in PostgreSQL/Supabase as part of the final gate.

## Release position

**Authentication/Authorization is materially hardened in the canonical source,
but the repository alone does not prove a production release gate.** The
remaining release claim is therefore: **verified statically / runtime backend
verification required**.

No migration file was created. No new file was created under `supabase/schema/`.
SQL remains centralized in the existing canonical schema and existing archive
layout.

## Additional authorization hardening in this pass

The canonical RLS source was re-audited for privileged mutations, not only self-service
writes. The following cross-tenant control-plane gaps were found and closed:

- `public.users` admin update/delete policies now bind target rows to the current
  database tenant, with `super_admin` as the explicit cross-tenant exception.
- `public.user_roles` selection and mutations are tenant-bound; inserts also require
  the referenced user and role to belong to the same current tenant unless the caller
  is `super_admin`.
- `public.roles` and `public.role_permissions` mutations are tenant-bound through the
  role row, with `super_admin` as the explicit cross-tenant exception.
- `public.tenant_settings` and `public.security_settings` mutations are tenant-bound.
- Global control-plane tables (`permissions`, `settings_kv`, `feature_flags`,
  `rate_limit_rules`, and tenant administration) are now writable by
  `super_admin` only. `cache_invalidation_queue` is denied to `authenticated`.
- `VALIDATION.sql` now contains explicit regression checks for tenant-scoped
  privileged writes and global authorization/control-plane write restrictions.

These are source-level authorization fixes. They still require execution of
`VALIDATION.sql` against the target Supabase/PostgreSQL environment to convert the
schema assertions into live-runtime evidence.
