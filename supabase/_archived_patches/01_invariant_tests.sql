-- =============================================================================
-- Section 8 Security Invariant Tests
--
-- Executes the AUTH-INVARIANT-01..07 checks and the Phase 35/36 test matrix
-- from EduZone_Authentication_Session_Security_Architecture.md, against the
-- REAL, unmodified supabase/schema/*.sql loaded into a local Postgres 16 via
-- 00_supabase_shim.sql. No app code, no mocks of the functions under test —
-- validate_user_session(), assert_valid_session(),
-- is_admin_with_session_validation(), and RLS on public.users are exercised
-- exactly as they are defined in the repo.
--
-- Each test prints PASS/FAIL. Run with:
--   psql ... -f 00_supabase_shim.sql -f 01_invariant_tests.sql
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS test;
GRANT USAGE ON SCHEMA test TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION test.assert(p_name text, p_condition boolean) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF p_condition THEN
    RAISE NOTICE 'PASS: %', p_name;
  ELSE
    RAISE WARNING 'FAIL: %', p_name;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION test.assert(text, boolean) TO anon, authenticated, service_role;

-- ─── Fixtures ────────────────────────────────────────────────────────────
-- (regions are already seeded by the schema itself — reuse the existing
-- primary region instead of inserting a competing one, since
-- uq_regions_primary allows only one is_primary=true row.)
DO $$
DECLARE
  v_region_id text;
BEGIN
  SELECT id INTO v_region_id FROM public.regions WHERE is_primary = true LIMIT 1;
  IF v_region_id IS NULL THEN
    INSERT INTO public.regions (id, label, is_active, is_primary)
    VALUES ('test-region', 'Test Region', true, true);
    v_region_id := 'test-region';
  END IF;

  INSERT INTO public.tenants (id, slug, name, region_id, data_residency)
  VALUES
    ('11111111-1111-1111-1111-111111111111', 'tenant-a', 'Tenant A', v_region_id, v_region_id),
    ('22222222-2222-2222-2222-222222222222', 'tenant-b', 'Tenant B', v_region_id, v_region_id)
  ON CONFLICT (id) DO NOTHING;

  -- auth.users rows (FK target for public.users.id)
  INSERT INTO auth.users (id, email) VALUES
    ('aaaaaaaa-0000-0000-0000-000000000001', 'active.student@tenant-a.test'),
    ('aaaaaaaa-0000-0000-0000-000000000002', 'inactive.student@tenant-a.test'),
    ('aaaaaaaa-0000-0000-0000-000000000003', 'deleted.student@tenant-a.test'),
    ('aaaaaaaa-0000-0000-0000-000000000004', 'admin@tenant-a.test'),
    ('aaaaaaaa-0000-0000-0000-000000000005', 'other.student@tenant-a.test'),
    ('aaaaaaaa-0000-0000-0000-000000000006', 'student.tenantb@tenant-b.test')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.users (id, tenant_id, primary_role, account_status, token_version, first_name, email, region_id)
  VALUES
    ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'student', 'active',    3, 'Active',   'active.student@tenant-a.test',   v_region_id),
    ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'student', 'suspended', 0, 'Inactive', 'inactive.student@tenant-a.test', v_region_id),
    ('aaaaaaaa-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'student', 'active',    0, 'Deleted',  'deleted.student@tenant-a.test',  v_region_id),
    ('aaaaaaaa-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'admin',   'active',    1, 'Admin',    'admin@tenant-a.test',            v_region_id),
    ('aaaaaaaa-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111', 'student', 'active',    0, 'Other',    'other.student@tenant-a.test',    v_region_id),
    ('aaaaaaaa-0000-0000-0000-000000000006', '22222222-2222-2222-2222-222222222222', 'student', 'active',    0, 'TenantB',  'student.tenantb@tenant-b.test',  v_region_id)
  ON CONFLICT (id) DO NOTHING;

  UPDATE public.users SET deleted_at = now() WHERE id = 'aaaaaaaa-0000-0000-0000-000000000003';
END $$;

-- =============================================================================
-- Test 1 — valid JWT + matching DB token_version → ALLOW
-- =============================================================================
SELECT test.set_jwt_claims(jsonb_build_object(
  'sub', 'aaaaaaaa-0000-0000-0000-000000000001',
  'role', 'authenticated',
  'token_version', 3
));
SELECT test.assert(
  'Test 1: valid JWT + matching DB token_version -> validate_user_session() = true',
  public.validate_user_session() = true
);

-- =============================================================================
-- Test 2 — valid JWT but DB token_version has since been incremented (e.g.
-- password change / forced logout) → DENY. This is the whole point of
-- AUTH-INVARIANT-02 ("Token revocation"): DB wins over a still-valid JWT.
-- =============================================================================
SELECT test.set_jwt_claims(jsonb_build_object(
  'sub', 'aaaaaaaa-0000-0000-0000-000000000001',
  'role', 'authenticated',
  'token_version', 1   -- stale — DB is now at 3
));
SELECT test.assert(
  'Test 2: stale token_version in JWT (DB has moved on) -> validate_user_session() = false',
  public.validate_user_session() = false
);

-- =============================================================================
-- Test 3 — JWT missing token_version entirely -> fail closed, not "assume ok"
-- =============================================================================
SELECT test.set_jwt_claims(jsonb_build_object(
  'sub', 'aaaaaaaa-0000-0000-0000-000000000001',
  'role', 'authenticated'
  -- no token_version claim at all
));
SELECT test.assert(
  'Test 3: JWT missing token_version -> validate_user_session() = false (fail closed)',
  public.validate_user_session() = false
);

-- =============================================================================
-- Test 4 — inactive (suspended) account -> DENY even with correct token_version
-- =============================================================================
SELECT test.set_jwt_claims(jsonb_build_object(
  'sub', 'aaaaaaaa-0000-0000-0000-000000000002',
  'role', 'authenticated',
  'token_version', 0
));
SELECT test.assert(
  'Test 4: suspended account -> validate_user_session() = false',
  public.validate_user_session() = false
);

-- =============================================================================
-- Test 5 — soft-deleted account -> DENY
-- =============================================================================
SELECT test.set_jwt_claims(jsonb_build_object(
  'sub', 'aaaaaaaa-0000-0000-0000-000000000003',
  'role', 'authenticated',
  'token_version', 0
));
SELECT test.assert(
  'Test 5: soft-deleted account -> validate_user_session() = false',
  public.validate_user_session() = false
);

-- =============================================================================
-- Test 6 — unauthenticated (no JWT at all) -> DENY
-- =============================================================================
SELECT test.clear_jwt_claims();
SELECT test.assert(
  'Test 6: no session at all -> validate_user_session() = false',
  public.validate_user_session() = false
);

-- =============================================================================
-- Test 7 — student calling an admin-gated check -> DENY
-- =============================================================================
SELECT test.set_jwt_claims(jsonb_build_object(
  'sub', 'aaaaaaaa-0000-0000-0000-000000000001',
  'role', 'authenticated',
  'token_version', 3
));
SELECT test.assert(
  'Test 7: student session -> is_admin_with_session_validation() = false',
  public.is_admin_with_session_validation() = false
);

-- =============================================================================
-- Test 8 — admin session -> is_admin_with_session_validation() = true
--
-- Reads token_version live rather than hardcoding it: Test 11 below
-- mutates this same user's token_version, so hardcoding would only be
-- correct on a single run against a freshly-seeded database. Reading it
-- live makes this test idempotent under repeated runs, and is also more
-- realistic — a freshly-issued JWT always carries whatever token_version
-- is current at issuance time.
-- =============================================================================
SELECT test.set_jwt_claims(jsonb_build_object(
  'sub', 'aaaaaaaa-0000-0000-0000-000000000004',
  'role', 'authenticated',
  'token_version', (SELECT token_version FROM public.users WHERE id = 'aaaaaaaa-0000-0000-0000-000000000004')
));
SELECT test.assert(
  'Test 8: admin session -> is_admin_with_session_validation() = true',
  public.is_admin_with_session_validation() = true
);

-- =============================================================================
-- Test 9 — RLS: a student can read their OWN row but not another student's
-- row in the same tenant (AUTH-INVARIANT-04/05 exercised via real RLS, not
-- just the helper function in isolation).
-- =============================================================================
SET ROLE authenticated;
SELECT test.set_jwt_claims(jsonb_build_object(
  'sub', 'aaaaaaaa-0000-0000-0000-000000000001',
  'role', 'authenticated',
  'token_version', 3
));
SELECT test.assert(
  'Test 9a: student can SELECT own row via RLS',
  (SELECT count(*) FROM public.users WHERE id = 'aaaaaaaa-0000-0000-0000-000000000001') = 1
);
SELECT test.assert(
  'Test 9b: student CANNOT SELECT another student''s row via RLS',
  (SELECT count(*) FROM public.users WHERE id = 'aaaaaaaa-0000-0000-0000-000000000005') = 0
);
RESET ROLE;

-- =============================================================================
-- Test 10 — RLS tenant isolation: a student in tenant B cannot see a user
-- row that belongs to tenant A (AUTH-INVARIANT-03).
-- =============================================================================
SET ROLE authenticated;
SELECT test.set_jwt_claims(jsonb_build_object(
  'sub', 'aaaaaaaa-0000-0000-0000-000000000006',
  'role', 'authenticated',
  'token_version', 0
));
SELECT test.assert(
  'Test 10: tenant-B student cannot see tenant-A user rows via RLS',
  (SELECT count(*) FROM public.users WHERE tenant_id = '11111111-1111-1111-1111-111111111111') = 0
);
RESET ROLE;

-- =============================================================================
-- Test 11 — old JWT after role revocation: token_version bumps on role
-- change (trg_increment_token_version_on_role_change), so a JWT issued
-- before the change is stale and must fail even though it "looks" valid.
--
-- Uses a fixed sentinel value (not `+ 1`) so this block is idempotent under
-- repeated runs against the same database — `+1` would silently drift the
-- "old" JWT further out of date on every re-run without ever failing loud.
-- =============================================================================
DO $$
BEGIN
  UPDATE public.users
  SET token_version = 999
  WHERE id = 'aaaaaaaa-0000-0000-0000-000000000004';
END $$;

SELECT test.set_jwt_claims(jsonb_build_object(
  'sub', 'aaaaaaaa-0000-0000-0000-000000000004',
  'role', 'authenticated',
  'token_version', 1   -- the ORIGINAL seed value — always stale after the update above
));
SELECT test.assert(
  'Test 11: JWT token_version predating a revocation-triggering change -> DENY',
  public.validate_user_session() = false
);

SELECT test.clear_jwt_claims();
RESET ROLE;

-- =============================================================================
-- Test 12 — CRITICAL FINDING, confirmed live against the real schema:
--
-- users_select_merged (09_rls.sql) contains this branch:
--   validate_user_session() AND (id = auth.uid() OR tenant_matches_jwt(tenant_id))
--
-- tenant_matches_jwt(tenant_id) means "this row's tenant is MY tenant" — not
-- "this row is MINE". Combined with OR, that branch grants every
-- authenticated user with a valid session SELECT on every user row in their
-- own tenant, completely bypassing the policy's other, narrower branches
-- (self, admin, teacher-of-enrolled-student). This is a full same-tenant
-- user-profile disclosure bug — violates AUTH-INVARIANT-04 ("authenticated
-- != authorized").
--
-- This test is written to PASS once the fix (removing that branch — see
-- 02_proposed_fix_users_select_rls.sql, NOT applied to supabase/schema/ by
-- this suite) is in place, and to FAIL loudly against the current,
-- unmodified policy so this stays a regression test either way.
-- =============================================================================
SET ROLE authenticated;
SELECT test.set_jwt_claims(jsonb_build_object(
  'sub', 'aaaaaaaa-0000-0000-0000-000000000001',
  'role', 'authenticated',
  'token_version', 3
));
SELECT test.assert(
  'Test 12 [CRITICAL]: same-tenant student CANNOT read another student''s full profile row',
  (SELECT count(*) FROM public.users WHERE id = 'aaaaaaaa-0000-0000-0000-000000000005') = 0
);
RESET ROLE;

SELECT test.clear_jwt_claims();
