-- =============================================================================
-- PROPOSED FIX — NOT APPLIED to supabase/schema/ or any live database by
-- this session. This file is for review. Apply via your normal migration
-- process once approved.
--
-- Finding:  CRITICAL — same-tenant user-profile disclosure via
--           public.users_select_merged (defined in supabase/schema/09_rls.sql,
--           around line 1481).
--
-- Root cause: the policy's third branch is
--
--     validate_user_session()
--     AND (id = (select auth.uid()) OR tenant_matches_jwt(tenant_id))
--
--   tenant_matches_jwt(tenant_id) answers "does this ROW's tenant match MY
--   tenant?" — not "is this row mine?". Combined with a bare OR, ANY
--   authenticated user with a valid session can SELECT every user row
--   (name, role, status, timestamps, etc.) in their own tenant, regardless
--   of role. This bypasses the policy's other three branches, which
--   correctly scope visibility to: self, admin, and teacher-of-enrolled-
--   student.
--
-- Confirmed live (not just read from source) against the real, unmodified
-- 09_rls.sql loaded into Postgres 16 — see test/security/01_invariant_tests.sql,
-- Test 9b / Test 12. Before this fix: FAIL (student read another student's
-- row). After this fix, applied to the same test database: PASS — and a
-- regression check confirmed admin/self/teacher visibility are unaffected.
--
-- Fix: drop the offending branch. It is redundant even for its likely
-- intended purpose:
--   - "self" is already covered by `id = get_auth_user_id()` earlier in the
--     same USING clause.
--   - "admin" is already covered by `is_admin_with_session_validation()`.
--   - "teacher can see their enrolled students" is already covered by the
--     EXISTS(...) branch immediately below the one being removed.
-- No other legitimate access pattern is served by
-- `OR tenant_matches_jwt(tenant_id)` here, so removing it does not require
-- adding anything back.
-- =============================================================================

DROP POLICY IF EXISTS users_select_merged ON public.users;
CREATE POLICY users_select_merged ON public.users
  FOR SELECT TO authenticated
  USING (
    deleted_at IS NULL
    AND (
      public.is_admin_with_session_validation()
      OR (id = public.get_auth_user_id())
      OR (
        users.tenant_id = public.get_current_tenant_id()
        AND EXISTS (
          SELECT 1 FROM public.courses c
          JOIN public.enrollments e ON e.course_id = c.id
          WHERE c.teacher_id = public.get_auth_user_id()
            AND e.user_id = users.id
            AND c.tenant_id = public.get_current_tenant_id()
            AND e.status = 'active'
        )
      )
    )
  );

-- =============================================================================
-- Before applying to a real environment:
--
-- 1. Grep the codebase (Flutter + any Edge Functions/RPCs) for anything that
--    currently relies on a student being able to read a classmate's
--    `public.users` row directly (e.g. a "who's in my class" roster feature
--    querying users directly instead of through a dedicated, deliberately-
--    scoped RPC/view). If such a feature exists and is intentional, it needs
--    its OWN narrow, audited policy/RPC — not a blanket tenant-wide read on
--    the core users table. I did not find such a caller in
--    lib/features/**, but I did not exhaustively grep the Supabase Edge
--    Functions in supabase/functions/ for this specific pattern.
-- 2. Apply through your normal migration path (this repo's
--    supabase/migrations/ appears to have a "no migrations without
--    explicit instruction" note from a prior, unrelated task — respect
--    whatever your current process is).
-- 3. Re-run test/security/01_invariant_tests.sql (or your pgTAP/CI
--    equivalent) against staging before production.
-- =============================================================================
