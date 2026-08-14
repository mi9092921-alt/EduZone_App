-- ============================================================================
-- Schema Validation & Health Check
-- Run this AFTER applying schema and seed data
-- ============================================================================

CREATE TEMP TABLE validation_results (
  check_name text,
  status text,
  details text
);

-- Check 1: System Tenant Exists
DO $$
DECLARE
  v_exists boolean;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM public.tenants 
    WHERE id = '00000000-0000-0000-0000-000000000001'
  ) INTO v_exists;
  
  INSERT INTO validation_results VALUES (
    'System Tenant Exists',
    CASE WHEN v_exists THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN v_exists 
      THEN 'System tenant created successfully'
      ELSE 'CRITICAL: System tenant missing - auth will fail'
    END
  );
END $$;

-- Check 2: System Roles Created
DO $$
DECLARE
  v_count int;
BEGIN
  SELECT COUNT(*) INTO v_count FROM public.roles 
  WHERE tenant_id = '00000000-0000-0000-0000-000000000001';
  
  INSERT INTO validation_results VALUES (
    'System Roles Exist',
    CASE WHEN v_count >= 4 THEN 'PASS' ELSE 'FAIL' END,
    'Found ' || v_count || ' system roles (expected >= 4)'
  );
END $$;

-- Check 3: RLS Enabled on Mutable Tables
DO $$
DECLARE
  v_tables_without_rls text[];
BEGIN
  SELECT ARRAY_AGG(DISTINCT c.relname)
  INTO v_tables_without_rls
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relkind = 'r'
    AND NOT c.relrowsecurity;
  
  INSERT INTO validation_results VALUES (
    'RLS Enabled on All Mutable Tables',
    CASE WHEN v_tables_without_rls IS NULL OR array_length(v_tables_without_rls, 1) = 0 
      THEN 'PASS' ELSE 'WARN' END,
    COALESCE('Tables with RLS disabled: ' || array_to_string(v_tables_without_rls, ', '),
             'RLS is enabled on all public tables')
  );
END $$;

-- Check 4: check_user_access RPC Exists
DO $$
DECLARE
  v_exists boolean;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM information_schema.routines 
    WHERE routine_name = 'check_user_access' 
      AND routine_schema = 'public'
  ) INTO v_exists;
  
  INSERT INTO validation_results VALUES (
    'check_user_access RPC Exists',
    CASE WHEN v_exists THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN v_exists 
      THEN 'RPC is available'
      ELSE 'CRITICAL: RPC missing - auth hydration will fail'
    END
  );
END $$;

-- Check 5: check_user_access Grants
DO $$
DECLARE
  v_authenticated_grant boolean;
  v_anon_grant boolean;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM information_schema.role_routine_grants
    WHERE routine_name = 'check_user_access'
      AND grantee = 'authenticated'
  ) INTO v_authenticated_grant;
  
  SELECT EXISTS(
    SELECT 1 FROM information_schema.role_routine_grants
    WHERE routine_name = 'check_user_access'
      AND grantee = 'anon'
  ) INTO v_anon_grant;
  
  INSERT INTO validation_results VALUES (
    'check_user_access Permissions',
    CASE 
      WHEN v_authenticated_grant AND NOT v_anon_grant THEN 'PASS'
      WHEN NOT v_anon_grant THEN 'WARN'
      ELSE 'FAIL'
    END,
    CASE 
      WHEN v_authenticated_grant AND NOT v_anon_grant 
        THEN 'authenticated: GRANT, anon: REVOKE (correct)'
      WHEN v_authenticated_grant AND v_anon_grant
        THEN 'WARNING: anon has access to check_user_access (should be revoked)'
      WHEN NOT v_authenticated_grant
        THEN 'CRITICAL: authenticated cannot execute check_user_access'
      ELSE 'anon only has access (incorrect)'
    END
  );
END $$;

-- Check 6: Core Tables Exist
DO $$
DECLARE
  v_missing_tables text[];
  v_required_tables text[] := ARRAY['users', 'tenants', 'roles', 'courses', 'sections', 'lessons', 'audit_logs'];
BEGIN
  SELECT ARRAY_AGG(t)
  INTO v_missing_tables
  FROM UNNEST(v_required_tables) t
  WHERE NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = t
  );
  
  INSERT INTO validation_results VALUES (
    'Core Tables Exist',
    CASE WHEN v_missing_tables IS NULL OR array_length(v_missing_tables, 1) = 0 
      THEN 'PASS' ELSE 'FAIL' END,
    COALESCE('Missing tables: ' || array_to_string(v_missing_tables, ', '),
             'All core tables present')
  );
END $$;

-- Check 7: System Settings Exist
DO $$
DECLARE
  v_settings_count int;
  v_table_exists boolean;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'system_settings'
  ) INTO v_table_exists;
  
  IF v_table_exists THEN
    SELECT COUNT(*) INTO v_settings_count FROM public.system_settings;
    
    INSERT INTO validation_results VALUES (
      'System Settings Table Populated',
      CASE WHEN v_settings_count > 0 THEN 'PASS' ELSE 'WARN' END,
      'Found ' || v_settings_count || ' system settings'
    );
  ELSE
    INSERT INTO validation_results VALUES (
      'System Settings Table Populated',
      'WARN',
      'system_settings table does not exist (may be optional)'
    );
  END IF;
END $$;

-- Check 8: SECURITY DEFINER Functions Have search_path
DO $$
DECLARE
  v_unsafe_functions text[];
BEGIN
  SELECT ARRAY_AGG(p.proname)
  INTO v_unsafe_functions
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
    AND p.prosecdef = true
    AND (p.proconfig IS NULL OR p.proconfig::text NOT LIKE '%search_path%');
  
  INSERT INTO validation_results VALUES (
    'SECURITY DEFINER Functions Have search_path',
    CASE WHEN v_unsafe_functions IS NULL OR array_length(v_unsafe_functions, 1) = 0
      THEN 'PASS' ELSE 'WARN' END,
    COALESCE('Unsafe functions (need SET search_path): ' || array_to_string(v_unsafe_functions, ', '),
             'All SECURITY DEFINER functions have proper search_path')
  );
END $$;

-- Check 9: Todos Soft Delete RLS Is Safe
DO $$
DECLARE
  v_rls_enabled boolean;
  v_rls_forced boolean;
  v_policy_count int;
  v_for_all_count int;
  v_delete_count int;
  v_expected_count int;
  v_canonical_count int;
  v_can_delete boolean;
BEGIN
  SELECT c.relrowsecurity, c.relforcerowsecurity
  INTO v_rls_enabled, v_rls_forced
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname = 'todos';

  SELECT count(*) INTO v_policy_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'todos';

  SELECT count(*) INTO v_for_all_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'todos'
    AND cmd = 'ALL';

  SELECT count(*) INTO v_delete_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'todos'
    AND cmd = 'DELETE';

  SELECT count(*) INTO v_expected_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'todos'
    AND policyname = 'todos_access';

  SELECT count(*) INTO v_canonical_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'todos'
    AND policyname = 'todos_access'
    AND cmd = 'ALL'
    AND roles = ARRAY['authenticated'::name];

  SELECT has_table_privilege('authenticated', 'public.todos', 'DELETE')
  INTO v_can_delete;

  INSERT INTO validation_results VALUES (
    'Todos Soft Delete RLS Safe',
    CASE
      WHEN v_rls_enabled
        AND v_rls_forced
        AND v_policy_count = 2
        AND v_expected_count = 1
        AND v_canonical_count = 1
        AND v_for_all_count = 2
        AND v_delete_count = 0
        AND NOT v_can_delete
        THEN 'PASS'
      ELSE 'FAIL'
    END,
    'rls_enabled=' || COALESCE(v_rls_enabled::text, 'null')
      || ', rls_forced=' || COALESCE(v_rls_forced::text, 'null')
      || ', policy_count=' || v_policy_count
      || ', expected_policies=' || v_expected_count
      || ', canonical_policy=' || v_canonical_count
      || ', for_all_policies=' || v_for_all_count
      || ', delete_policies=' || v_delete_count
      || ', authenticated_can_delete=' || COALESCE(v_can_delete::text, 'null')
  );
END $$;

-- Check 10: Tenant authorization is DB-authoritative.
DO $$
DECLARE
  v_tenant_fn text;
  v_assert_fn text;
  v_match_fn text;
  v_unsafe boolean;
BEGIN
  SELECT pg_get_functiondef(p.oid)
    INTO v_tenant_fn
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname = 'get_current_tenant_id'
     AND pg_get_function_identity_arguments(p.oid) = ''
   LIMIT 1;

  SELECT pg_get_functiondef(p.oid)
    INTO v_assert_fn
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname = 'assert_tenant'
     AND pg_get_function_identity_arguments(p.oid) = ''
   LIMIT 1;

  SELECT pg_get_functiondef(p.oid)
    INTO v_match_fn
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname = 'tenant_matches_jwt'
     AND pg_get_function_identity_arguments(p.oid) = 'p_tenant_id uuid'
   LIMIT 1;

  v_unsafe := coalesce(v_tenant_fn, '') ILIKE '%auth.jwt()%tenant_id%'
           OR coalesce(v_assert_fn, '') ILIKE '%auth.jwt()%tenant_id%'
           OR coalesce(v_match_fn, '') ILIKE '%auth.jwt()%tenant_id%'
           OR coalesce(v_match_fn, '') ILIKE '%app_metadata%tenant_id%';

  INSERT INTO validation_results VALUES (
    'Tenant Authorization Is DB-Authoritative',
    CASE
      WHEN v_tenant_fn IS NOT NULL
       AND v_assert_fn IS NOT NULL
       AND v_match_fn IS NOT NULL
       AND NOT v_unsafe
      THEN 'PASS' ELSE 'FAIL'
    END,
    CASE WHEN v_unsafe
      THEN 'CRITICAL: tenant authorization still depends on JWT tenant claims'
      ELSE 'Tenant context helpers resolve authorization from database state'
    END
  );
END $$;

-- Check 11: Every public RLS-protected table has the canonical session baseline.
DO $$
DECLARE
  v_missing text[];
BEGIN
  SELECT array_agg(c.relname ORDER BY c.relname)
    INTO v_missing
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public'
     AND c.relkind IN ('r', 'p')
     AND c.relrowsecurity
     AND NOT EXISTS (
       SELECT 1
         FROM pg_policies p
        WHERE p.schemaname = 'public'
          AND p.tablename = c.relname
          AND p.policyname LIKE 'auth_session_required_%'
     );

  INSERT INTO validation_results VALUES (
    'Canonical Auth Session Baseline Coverage',
    CASE WHEN v_missing IS NULL THEN 'PASS' ELSE 'FAIL' END,
    COALESCE(
      'Missing baseline policies: ' || array_to_string(v_missing, ', '),
      'Every public RLS-protected table has a restrictive session-validity policy'
    )
  );
END $$;



-- Check 12: Authentication hook is callable only by Supabase Auth / trusted backend.
DO $$
DECLARE
  v_hook_exists boolean;
  v_schema_usage boolean;
  v_auth_admin_exec boolean;
  v_anon_exec boolean;
  v_authenticated_exec boolean;
BEGIN
  SELECT EXISTS(
    SELECT 1
    FROM information_schema.routines
    WHERE routine_schema = 'public'
      AND routine_name = 'custom_access_token'
      AND specific_name LIKE 'custom_access_token%'
  ) INTO v_hook_exists;

  SELECT has_schema_privilege('supabase_auth_admin', 'public', 'USAGE')
    INTO v_schema_usage;
  SELECT has_function_privilege(
    'supabase_auth_admin',
    'public.custom_access_token(jsonb)',
    'EXECUTE'
  ) INTO v_auth_admin_exec;
  SELECT has_function_privilege(
    'anon',
    'public.custom_access_token(jsonb)',
    'EXECUTE'
  ) INTO v_anon_exec;
  SELECT has_function_privilege(
    'authenticated',
    'public.custom_access_token(jsonb)',
    'EXECUTE'
  ) INTO v_authenticated_exec;

  INSERT INTO validation_results VALUES (
    'Custom Access Token Hook Permissions',
    CASE
      WHEN v_hook_exists
       AND v_schema_usage
       AND v_auth_admin_exec
       AND NOT v_anon_exec
       AND NOT v_authenticated_exec
      THEN 'PASS' ELSE 'FAIL'
    END,
    'hook=' || COALESCE(v_hook_exists::text, 'null')
      || ', schema_usage=' || COALESCE(v_schema_usage::text, 'null')
      || ', auth_admin_execute=' || COALESCE(v_auth_admin_exec::text, 'null')
      || ', anon_execute=' || COALESCE(v_anon_exec::text, 'null')
      || ', authenticated_execute=' || COALESCE(v_authenticated_exec::text, 'null')
  );
END $$;

-- Check 13: Sensitive tenant tables must not use permissive tenant-wide
-- authorization through tenant_matches_jwt(). Multiple permissive policies
-- are OR-combined by PostgreSQL, so one broad policy can defeat a narrower one.
DO $$
DECLARE
  v_bad text[];
BEGIN
  SELECT array_agg(tablename || ':' || policyname ORDER BY tablename, policyname)
    INTO v_bad
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename IN ('users', 'user_roles', 'courses', 'enrollments', 'user_progress')
    AND (
      coalesce(qual, '') ILIKE '%tenant_matches_jwt(%'
      OR coalesce(with_check, '') ILIKE '%tenant_matches_jwt(%'
    );

  INSERT INTO validation_results VALUES (
    'Sensitive Tables Avoid Tenant-Only JWT Authorization',
    CASE WHEN v_bad IS NULL THEN 'PASS' ELSE 'FAIL' END,
    COALESCE(
      'CRITICAL: permissive tenant_matches_jwt policies remain: '
        || array_to_string(v_bad, ', '),
      'No sensitive-table policy delegates row authorization to tenant_matches_jwt()'
    )
  );
END $$;

-- Check 14: Self-service writes must remain bound to the authenticated
-- tenant. This guards against policies that check auth.uid() but omit tenant
-- equality in either USING or WITH CHECK.
DO $$
DECLARE
  v_bad text[];
BEGIN
  SELECT array_agg(tablename || ':' || policyname ORDER BY tablename, policyname)
    INTO v_bad
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename IN ('enrollments', 'user_progress')
    AND (
      coalesce(qual, '') ILIKE '%user_id = (select auth.uid())%'
      OR coalesce(qual, '') ILIKE '%user_id = public.get_auth_user_id()%'
      OR coalesce(with_check, '') ILIKE '%user_id = (select auth.uid())%'
      OR coalesce(with_check, '') ILIKE '%user_id = public.get_auth_user_id()%'
    )
    AND coalesce(qual || ' ' || with_check, '') NOT ILIKE '%get_current_tenant_id()%'
    AND coalesce(qual || ' ' || with_check, '') NOT ILIKE '%assert_tenant()%';

  INSERT INTO validation_results VALUES (
    'Self-Service Writes Are Tenant-Bound',
    CASE WHEN v_bad IS NULL THEN 'PASS' ELSE 'FAIL' END,
    COALESCE(
      'CRITICAL: self-service policy lacks tenant binding: '
        || array_to_string(v_bad, ', '),
      'Self-service enrollment/progress policies require canonical tenant context'
    )
  );
END $$;

-- Display Results
SELECT * FROM validation_results ORDER BY check_name;

-- Summary
DO $$
DECLARE
  v_total int;
  v_pass int;
  v_fail int;
  v_warn int;
BEGIN
  SELECT COUNT(*), 
         COUNT(*) FILTER (WHERE status = 'PASS'),
         COUNT(*) FILTER (WHERE status = 'FAIL'),
         COUNT(*) FILTER (WHERE status = 'WARN')
  INTO v_total, v_pass, v_fail, v_warn
  FROM validation_results;
  
  RAISE NOTICE '';
  RAISE NOTICE '========== VALIDATION SUMMARY ==========';
  RAISE NOTICE 'Total Checks: %', v_total;
  RAISE NOTICE 'Passed:       % ✓', v_pass;
  RAISE NOTICE 'Failed:       % ✗', v_fail;
  RAISE NOTICE 'Warnings:     % ⚠', v_warn;
  RAISE NOTICE '========================================';
  
  IF v_fail > 0 THEN
    RAISE WARNING 'Schema validation failed - fix errors before deploying';
  END IF;
END $$;
