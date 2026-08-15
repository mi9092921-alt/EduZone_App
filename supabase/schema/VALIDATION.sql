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



-- Check 12A: Session revocation is tied to the real Supabase Auth session.
DO $$
DECLARE
  v_has_session_helper boolean;
  v_has_session_check boolean;
  v_helper_public boolean;
BEGIN
  SELECT EXISTS(
    SELECT 1
    FROM information_schema.routines
    WHERE routine_schema = 'private'
      AND routine_name = 'revoke_auth_sessions'
  ) INTO v_has_session_helper;

  SELECT pg_get_functiondef(p.oid) ILIKE '%auth.sessions s%session_id%'
  INTO v_has_session_check
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'validate_user_session'
    AND pg_get_function_identity_arguments(p.oid) = '';

  SELECT has_function_privilege(
    'authenticated',
    'private.revoke_auth_sessions(uuid)',
    'EXECUTE'
  ) OR has_function_privilege(
    'anon',
    'private.revoke_auth_sessions(uuid)',
    'EXECUTE'
  ) INTO v_helper_public;

  INSERT INTO validation_results VALUES (
    'Auth Session Revocation Boundary',
    CASE
      WHEN v_has_session_helper
       AND coalesce(v_has_session_check, false)
       AND NOT v_helper_public
      THEN 'PASS' ELSE 'FAIL'
    END,
    'private.revoke_auth_sessions exists; validate_user_session checks auth.sessions; helper is not API-callable'
  );
END $$;

-- Check 12B: All server-side token-version revocation paths also revoke
-- the underlying Supabase Auth sessions, preventing a refresh from minting
-- a fresh JWT after an application-level revocation.
DO $$
DECLARE
  v_missing text[];
BEGIN
  SELECT array_agg(routine_name ORDER BY routine_name)
    INTO v_missing
  FROM (VALUES
    ('trg_increment_token_version_on_role_change'),
    ('increment_token_version'),
    ('control_user_account'),
    ('worker_control_user_account'),
    ('logout_current_user'),
    ('reset_user_device'),
    ('worker_reset_user_device')
  ) AS expected(routine_name)
  WHERE NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = expected.routine_name
      AND pg_get_functiondef(p.oid) ILIKE '%private.revoke_auth_sessions(%'
  );

  INSERT INTO validation_results VALUES (
    'Token Revocation Paths Revoke Auth Sessions',
    CASE WHEN v_missing IS NULL THEN 'PASS' ELSE 'FAIL' END,
    COALESCE(
      'Missing auth-session revocation calls in: ' || array_to_string(v_missing, ', '),
      'All token/device/account revocation paths invalidate Supabase Auth sessions'
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


-- Check 15: Tenant-scoped privileged writes must bind target rows to the
-- current database tenant, with super_admin as the only cross-tenant exception.
DO $$
DECLARE
  v_bad text[];
BEGIN
  SELECT array_agg(tablename || ':' || policyname ORDER BY tablename, policyname)
    INTO v_bad
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename IN (
      'users', 'roles', 'role_permissions', 'user_roles',
      'tenant_settings', 'security_settings'
    )
    AND policyname IN (
      'users_admin_insert', 'users_admin_delete',
      'roles_admin_insert', 'roles_admin_update', 'roles_admin_delete',
      'role_permissions_admin_insert', 'role_permissions_admin_update',
      'role_permissions_admin_delete',
      'user_roles_admin_insert', 'user_roles_admin_update',
      'user_roles_admin_delete',
      'tenant_settings_admin_insert', 'tenant_settings_admin_update',
      'tenant_settings_admin_delete',
      'security_settings_admin_all'
    )
    AND NOT (
      (
        coalesce(qual, '') ILIKE '%is_current_user_super_admin()%'
        OR coalesce(with_check, '') ILIKE '%is_current_user_super_admin()%'
      )
      AND (
        coalesce(qual, '') ILIKE '%tenant_id = public.get_current_tenant_id()%'
        OR coalesce(with_check, '') ILIKE '%tenant_id = public.assert_tenant()%'
        OR coalesce(qual, '') ILIKE '%get_current_tenant_id()%'
        OR coalesce(with_check, '') ILIKE '%get_current_tenant_id()%'
        OR coalesce(with_check, '') ILIKE '%assert_tenant()%'
        OR (
          tablename = 'role_permissions'
          AND (
            coalesce(qual, '') ILIKE '%r.tenant_id = %get_current_tenant_id()%'
            OR coalesce(with_check, '') ILIKE '%r.tenant_id = %get_current_tenant_id()%'
          )
        )
      )
    );

  INSERT INTO validation_results VALUES (
    'Tenant-Scoped Privileged Writes Are Row-Bound',
    CASE WHEN v_bad IS NULL THEN 'PASS' ELSE 'FAIL' END,
    COALESCE(
      'CRITICAL: privileged policy lacks tenant-row binding: '
        || array_to_string(v_bad, ', '),
      'Tenant-scoped privileged writes require current tenant or explicit super_admin authority'
    )
  );
END $$;

-- Check 16: Global authorization/control-plane tables are not writable by
-- tenant admins. These tables affect every tenant or define authorization itself.
DO $$
DECLARE
  v_bad text[];
BEGIN
  SELECT array_agg(tablename || ':' || policyname ORDER BY tablename, policyname)
    INTO v_bad
  FROM pg_policies
  WHERE schemaname = 'public'
    AND (
      (tablename = 'permissions' AND policyname IN (
        'permissions_super_admin_insert',
        'permissions_super_admin_update',
        'permissions_super_admin_delete'
      ))
      OR
      (tablename = 'feature_flags' AND policyname IN (
        'feature_flags_admin_insert',
        'feature_flags_admin_update',
        'feature_flags_admin_delete'
      ))
      OR
      (tablename = 'settings_kv' AND policyname IN (
        'settings_admin_insert',
        'settings_admin_update',
        'settings_admin_delete'
      ))
      OR
      (tablename = 'rate_limit_rules' AND policyname = 'rate_limit_rules_admin')
      OR
      (tablename = 'tenants' AND policyname IN (
        'tenants_write_insert',
        'tenants_write_update',
        'tenants_write_delete'
      ))
    )
    AND NOT (
      (cmd = 'INSERT'
        AND coalesce(with_check, '') ILIKE '%is_current_user_super_admin()%')
      OR
      (cmd = 'UPDATE'
        AND coalesce(qual, '') ILIKE '%is_current_user_super_admin()%'
        AND coalesce(with_check, '') ILIKE '%is_current_user_super_admin()%')
      OR
      (cmd = 'DELETE'
        AND coalesce(qual, '') ILIKE '%is_current_user_super_admin()%')
      OR
      (cmd = 'ALL'
        AND coalesce(qual, '') ILIKE '%is_current_user_super_admin()%'
        AND coalesce(with_check, '') ILIKE '%is_current_user_super_admin()%')
    );

  INSERT INTO validation_results VALUES (
    'Global Authorization Tables Are Super-Admin Controlled',
    CASE WHEN v_bad IS NULL THEN 'PASS' ELSE 'FAIL' END,
    COALESCE(
      'CRITICAL: global control-plane policy is not restricted to super_admin: '
        || array_to_string(v_bad, ', '),
      'Global authorization/configuration mutations require server-validated super_admin authority'
    )
  );
END $$;

-- Check 17: Canonical auth function definitions must be unique.
-- Duplicate CREATE OR REPLACE definitions are dangerous because a partial
-- execution could leave an older, weaker implementation active.
DO $$
DECLARE
  v_logout_count int;
  v_bind_count int;
BEGIN
  SELECT COUNT(*) INTO v_logout_count
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'logout_current_user';

  SELECT COUNT(*) INTO v_bind_count
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'bind_device_for_current_user';

  INSERT INTO validation_results VALUES (
    'Canonical Auth Function Definitions Are Unique',
    CASE WHEN v_logout_count = 1 AND v_bind_count = 1 THEN 'PASS' ELSE 'FAIL' END,
    CASE
      WHEN v_logout_count = 1 AND v_bind_count = 1
        THEN 'logout_current_user and bind_device_for_current_user each have exactly one canonical definition'
      ELSE
        'CRITICAL: expected exactly one canonical definition; logout='
          || v_logout_count || ', bind_device=' || v_bind_count
    END
  );
END $$;


-- Check 18: Directly addressed sensitive partitions must be RLS-protected.
DO $$
DECLARE
  v_bad text[];
BEGIN
  SELECT array_agg(
           child_ns.nspname || '.' || child.relname
           ORDER BY child_ns.nspname, child.relname
         )
    INTO v_bad
  FROM pg_inherits i
  JOIN pg_class parent ON parent.oid = i.inhparent
  JOIN pg_namespace parent_ns ON parent_ns.oid = parent.relnamespace
  JOIN pg_class child ON child.oid = i.inhrelid
  JOIN pg_namespace child_ns ON child_ns.oid = child.relnamespace
  WHERE parent_ns.nspname IN ('public', 'audit')
    AND parent.relname IN (
      'sessions',
      'session_snapshots',
      'video_views',
      'user_location_logs',
      'activity_logs',
      'lesson_access_log',
      'alert_log'
    )
    AND NOT child.relrowsecurity;

  INSERT INTO validation_results VALUES (
    'Sensitive Partition Children Require RLS',
    CASE WHEN v_bad IS NULL THEN 'PASS' ELSE 'FAIL' END,
    COALESCE(
      'CRITICAL: direct partition access remains without RLS: '
        || array_to_string(v_bad, ', '),
      'All sensitive partition children have RLS enabled'
    )
  );
END $$;

-- Check 19: Sensitive partition children must not be directly granted to
-- PostgREST client roles. Normal access is through the parent table policies.
DO $$
DECLARE
  v_bad text[];
BEGIN
  SELECT array_agg(
           c.relname
           ORDER BY c.relname
         )
    INTO v_bad
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  JOIN pg_inherits i ON i.inhrelid = c.oid
  JOIN pg_class parent ON parent.oid = i.inhparent
  JOIN pg_namespace parent_ns ON parent_ns.oid = parent.relnamespace
  WHERE n.nspname IN ('public', 'audit')
    AND parent_ns.nspname IN ('public', 'audit')
    AND parent.relname IN (
      'sessions',
      'session_snapshots',
      'video_views',
      'user_location_logs',
      'activity_logs',
      'lesson_access_log',
      'alert_log'
    )
    AND (
      has_table_privilege('anon', c.oid, 'SELECT')
      OR has_table_privilege('anon', c.oid, 'INSERT')
      OR has_table_privilege('anon', c.oid, 'UPDATE')
      OR has_table_privilege('anon', c.oid, 'DELETE')
      OR has_table_privilege('authenticated', c.oid, 'SELECT')
      OR has_table_privilege('authenticated', c.oid, 'INSERT')
      OR has_table_privilege('authenticated', c.oid, 'UPDATE')
      OR has_table_privilege('authenticated', c.oid, 'DELETE')
    );

  INSERT INTO validation_results VALUES (
    'Sensitive Partition Children Have No Client Grants',
    CASE WHEN v_bad IS NULL THEN 'PASS' ELSE 'FAIL' END,
    COALESCE(
      'CRITICAL: client grants remain on sensitive partitions: '
        || array_to_string(v_bad, ', '),
      'anon/authenticated have no direct DML privileges on sensitive partition children'
    )
  );
END $$;


-- Check 20: Storage buckets and client write boundaries are explicit.
DO $$
DECLARE
  v_bad_buckets text[];
  v_avatar_policies int;
  v_non_avatar_client_policies int;
BEGIN
  SELECT array_agg(id ORDER BY id)
    INTO v_bad_buckets
  FROM storage.buckets
  WHERE (id IN ('reports', 'exports') AND public IS DISTINCT FROM false)
     OR (id = 'avatars' AND public IS DISTINCT FROM true);

  SELECT COUNT(*)
    INTO v_avatar_policies
  FROM pg_policies
  WHERE schemaname = 'storage'
    AND tablename = 'objects'
    AND policyname IN (
      'avatars_insert_own_folder',
      'avatars_update_own_folder',
      'avatars_delete_own_folder'
    );

  SELECT COUNT(*)
    INTO v_non_avatar_client_policies
  FROM pg_policies
  WHERE schemaname = 'storage'
    AND tablename = 'objects'
    AND policyname NOT LIKE 'avatars_%'
    AND (
      policyname ILIKE '%report%'
      OR policyname ILIKE '%export%'
    );

  INSERT INTO validation_results VALUES (
    'Storage Buckets And Client Write Boundaries',
    CASE
      WHEN v_bad_buckets IS NULL
       AND v_avatar_policies = 3
       AND v_non_avatar_client_policies = 0
      THEN 'PASS' ELSE 'FAIL' END,
    CASE
      WHEN v_bad_buckets IS NULL
       AND v_avatar_policies = 3
       AND v_non_avatar_client_policies = 0
      THEN 'avatars is intentionally public with owner-only writes; reports/exports are private and have no report/export client policies'
      ELSE 'CRITICAL: storage bucket visibility or client policy boundaries are not in the expected hardened state'
    END
  );
END $$;

-- Check 21: Rate-limit RPC has explicit least-privilege grants.
DO $$
DECLARE
  v_auth boolean;
  v_anon boolean;
  v_deprecated_auth boolean;
BEGIN
  SELECT has_function_privilege(
    'authenticated',
    'public.check_rate_limit(text, uuid, inet, uuid)',
    'EXECUTE'
  ) INTO v_auth;

  SELECT has_function_privilege(
    'anon',
    'public.check_rate_limit(text, uuid, inet, uuid)',
    'EXECUTE'
  ) INTO v_anon;

  SELECT has_function_privilege(
    'authenticated',
    'public.check_rate_limit(text, integer, integer)',
    'EXECUTE'
  ) INTO v_deprecated_auth;

  INSERT INTO validation_results VALUES (
    'Rate-Limit RPC Least Privilege',
    CASE
      WHEN v_auth AND NOT v_anon AND NOT v_deprecated_auth
        THEN 'PASS'
      ELSE 'FAIL'
    END,
    'check_rate_limit(authenticated)= ' || v_auth
      || ', anon= ' || v_anon
      || ', deprecated overload authenticated= ' || v_deprecated_auth
  );
END $$;

-- Check 22: get_lesson_content()/check_lesson_access() must be callable by
-- authenticated (see SECTION-09 FIX in 10_permissions.sql). Without this,
-- the get-lesson-content edge function's authorization RPC call fails
-- outright rather than actually being enforced.
DO $$
DECLARE
  v_missing text[];
BEGIN
  SELECT array_agg(fn ORDER BY fn)
    INTO v_missing
  FROM (VALUES
    ('public.get_lesson_content(uuid, inet, uuid)'),
    ('public.check_lesson_access(uuid)')
  ) AS f(fn)
  WHERE NOT has_function_privilege('authenticated', f.fn, 'EXECUTE');

  INSERT INTO validation_results VALUES (
    'Lesson Content RPCs Executable By Authenticated',
    CASE WHEN v_missing IS NULL THEN 'PASS' ELSE 'FAIL' END,
    COALESCE(
      'CRITICAL: authenticated cannot EXECUTE: ' || array_to_string(v_missing, ', '),
      'get_lesson_content and check_lesson_access are callable by authenticated'
    )
  );
END $$;

-- Check 23: sessions_admin_all / devices_admin_all must not grant
-- unscoped cross-tenant access via is_admin_with_session_validation() /
-- is_current_user_admin_lite() alone. The policy definition text must
-- reference the strictly-super_admin, tenant-unscoped helper
-- (is_current_user_super_admin_lite) for its cross-tenant branch.
DO $$
DECLARE
  v_bad text[];
BEGIN
  SELECT array_agg(polname ORDER BY polname)
    INTO v_bad
  FROM (
    SELECT pol.polname,
           pg_get_expr(pol.polqual, pol.polrelid) AS using_expr
    FROM pg_policy pol
    JOIN pg_class c ON c.oid = pol.polrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname IN ('sessions', 'devices')
      AND pol.polname IN ('sessions_admin_all', 'devices_admin_all')
  ) p
  WHERE using_expr IS NULL
     OR using_expr NOT ILIKE '%is_current_user_super_admin_lite%';

  INSERT INTO validation_results VALUES (
    'Sessions/Devices Admin Policy Is Tenant-Scoped',
    CASE WHEN v_bad IS NULL THEN 'PASS' ELSE 'FAIL' END,
    COALESCE(
      'CRITICAL: cross-tenant admin bypass not using super_admin-only check: '
        || array_to_string(v_bad, ', '),
      'sessions_admin_all / devices_admin_all restrict the unscoped branch to super_admin'
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
