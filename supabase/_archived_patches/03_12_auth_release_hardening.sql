-- ============================================================================
-- 12_auth_release_hardening.sql
-- Authentication / Authorization release hardening.
--
-- This file intentionally lives AFTER 09_rls.sql + 10_permissions.sql so it
-- can replace security-critical functions without editing the large canonical
-- source files. Keeping the hardening in a new ordered schema file also makes
-- the patch resilient to local formatting/context changes in 09_rls.sql.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- AUTHZ-SESSION-01: JWT tenant claims are context, not authorization.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.tenant_matches_jwt(p_tenant_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.role() <> 'service_role'
     AND NOT public.validate_user_session() THEN
    RETURN false;
  END IF;

  RETURN (
    (coalesce(
      auth.jwt()->'app_metadata'->>'tenant_id',
      '00000000-0000-0000-0000-000000000000'
    ))::uuid = p_tenant_id
    OR EXISTS (
      SELECT 1
      FROM public.users u
      WHERE u.id = auth.uid()
        AND u.tenant_id = p_tenant_id
        AND u.deleted_at IS NULL
        AND u.account_status = 'active'
    )
    OR EXISTS (
      SELECT 1
      FROM public.user_roles ur
      WHERE ur.user_id = auth.uid()
        AND ur.tenant_id = p_tenant_id
        AND ur.is_active = true
        AND ur.role_id IN (
          SELECT id FROM public.roles
          WHERE name IN ('admin', 'super_admin', 'tenant_admin')
        )
    )
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- AUTHZ-SESSION-02: permission evaluation must never bless a revoked JWT.
-- service_role is retained for trusted workers/admin backends that evaluate
-- an initiator's permissions explicitly.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.user_has_permission(
  p_user_id uuid,
  p_permission text,
  p_tenant_id uuid DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.role() <> 'service_role' THEN
    IF p_user_id IS DISTINCT FROM auth.uid() THEN
      RETURN false;
    END IF;
    IF NOT public.validate_user_session() THEN
      RETURN false;
    END IF;
  END IF;

  RETURN (
    EXISTS (
      SELECT 1
      FROM public.user_permission_cache pc
      WHERE pc.user_id = p_user_id
        AND pc.permission_name = p_permission
        AND pc.tenant_id = coalesce(p_tenant_id, public.system_tenant_id())
        AND (pc.expires_at IS NULL OR pc.expires_at > pg_catalog.now())
    )
    OR EXISTS (
      SELECT 1
      FROM public.user_roles ur
      JOIN public.role_permissions rp ON rp.role_id = ur.role_id
      JOIN public.permissions pm ON pm.id = rp.permission_id
      WHERE ur.user_id = p_user_id
        AND ur.is_active = true
        AND (ur.expires_at IS NULL OR ur.expires_at > pg_catalog.now())
        AND pm.name = p_permission
        AND ur.tenant_id = coalesce(p_tenant_id, public.system_tenant_id())
    )
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- AUTH-REV-01: logout must revoke the current JWT, not just close a session
-- row. The next request with the old token fails validate_user_session().
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.logout_current_user()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN;
  END IF;

  UPDATE public.users
     SET token_version = token_version + 1,
         updated_at = pg_catalog.now()
   WHERE id = auth.uid()
     AND deleted_at IS NULL;

  PERFORM public.terminate_user_sessions(auth.uid(), 'self_logout');
END;
$$;

-- ---------------------------------------------------------------------------
-- AUTH-DEV-01: device binding is serialized per user so the max-device
-- check and insert cannot race across concurrent login/rebind requests.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.bind_device_for_current_user(
  p_device_id text,
  p_device_info jsonb DEFAULT '{}',
  p_platform text DEFAULT NULL,
  p_fingerprint_version text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_tenant_id uuid := public.get_current_tenant_id();
  v_max integer := coalesce(
    (public.get_setting('max_devices_per_user') #>> '{}')::integer,
    1
  );
  v_count integer;
  v_device_info jsonb := coalesce(p_device_info, '{}');
  v_fingerprint_version text;
BEGIN
  IF v_uid IS NULL OR v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  IF NOT public.validate_user_session() THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = v_uid
      AND tenant_id = v_tenant_id
      AND deleted_at IS NULL
      AND account_status = 'active'
  ) THEN
    RAISE EXCEPTION 'TENANT_MISMATCH';
  END IF;

  IF btrim(coalesce(p_device_id, '')) = '' THEN
    RAISE EXCEPTION 'INVALID_DEVICE_ID';
  END IF;

  v_fingerprint_version := coalesce(
    nullif(btrim(p_fingerprint_version), ''),
    nullif(btrim(v_device_info ->> 'fingerprint_version'), ''),
    'v1'
  );

  IF v_fingerprint_version NOT IN ('v1', 'v2') THEN
    RAISE EXCEPTION 'INVALID_FINGERPRINT_VERSION';
  END IF;

  INSERT INTO public.session_locks (user_id)
  VALUES (v_uid)
  ON CONFLICT (user_id) DO NOTHING;

  PERFORM 1
  FROM public.session_locks
  WHERE user_id = v_uid
  FOR UPDATE;

  IF EXISTS (
    SELECT 1
    FROM public.devices
    WHERE device_id = p_device_id
      AND user_id <> v_uid
      AND is_active = true
  ) THEN
    RAISE EXCEPTION 'DEVICE_ALREADY_BOUND';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.devices
    WHERE user_id = v_uid
      AND tenant_id = v_tenant_id
      AND device_id = p_device_id
  ) THEN
    UPDATE public.devices
       SET last_seen = pg_catalog.now(),
           platform = coalesce(p_platform, platform),
           fingerprint_version = v_fingerprint_version,
           device_info = v_device_info,
           is_active = true
     WHERE user_id = v_uid
       AND tenant_id = v_tenant_id
       AND device_id = p_device_id;

    RETURN jsonb_build_object('status', 'verified');
  END IF;

  SELECT count(*)
    INTO v_count
    FROM public.devices
   WHERE user_id = v_uid
     AND tenant_id = v_tenant_id
     AND is_active = true;

  IF v_count >= v_max THEN
    RAISE EXCEPTION 'MAX_DEVICES_REACHED';
  END IF;

  INSERT INTO public.devices (
    user_id,
    tenant_id,
    device_id,
    fingerprint_version,
    platform,
    device_info
  )
  VALUES (
    v_uid,
    v_tenant_id,
    p_device_id,
    v_fingerprint_version,
    p_platform,
    v_device_info
  );

  RETURN jsonb_build_object('status', 'bound');
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'DEVICE_ALREADY_BOUND';
END;
$$;

-- ---------------------------------------------------------------------------
-- AUTHZ-STUDENT-01: student-only application access is decided server-side
-- at the same gate the Flutter startup/login flow already calls.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_user_access()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_user public.users%ROWTYPE;
  v_maintenance_excluded_roles text[] := ARRAY[]::text[];
  v_maintenance_excluded_users uuid[] := ARRAY[]::uuid[];
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'unauthenticated');
  END IF;

  SELECT *
    INTO v_user
    FROM public.users
   WHERE id = v_uid;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'user_not_found');
  END IF;

  IF v_user.deleted_at IS NOT NULL THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', 'deleted',
      'token_version', v_user.token_version
    );
  END IF;

  IF v_user.account_status <> 'active' THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', 'account_' || v_user.account_status,
      'message', v_user.lock_reason,
      'until', v_user.suspension_until,
      'suspensionUntil', v_user.suspension_until,
      'token_version', v_user.token_version
    );
  END IF;

  IF NOT public.validate_user_session() THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', 'token_version_mismatch',
      'token_version', v_user.token_version
    );
  END IF;

  IF v_user.primary_role <> 'student' THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', 'unauthenticated',
      'role', v_user.primary_role,
      'token_version', v_user.token_version
    );
  END IF;

  IF coalesce((public.get_setting('maintenance_mode') #>> '{}')::boolean, false) THEN
    SELECT coalesce(array_agg(value), ARRAY[]::text[])
      INTO v_maintenance_excluded_roles
      FROM jsonb_array_elements_text(
        CASE
          WHEN jsonb_typeof(public.get_setting('maintenance_excluded_roles')) = 'array'
          THEN public.get_setting('maintenance_excluded_roles')
          ELSE '[]'::jsonb
        END
      ) AS value;

    SELECT coalesce(array_agg(value::uuid), ARRAY[]::uuid[])
      INTO v_maintenance_excluded_users
      FROM jsonb_array_elements_text(
        CASE
          WHEN jsonb_typeof(public.get_setting('maintenance_excluded_users')) = 'array'
          THEN public.get_setting('maintenance_excluded_users')
          ELSE '[]'::jsonb
        END
      ) AS value;

    IF NOT (
      v_user.primary_role = ANY(v_maintenance_excluded_roles)
      OR v_user.id = ANY(v_maintenance_excluded_users)
    ) THEN
      RETURN jsonb_build_object(
        'allowed', false,
        'reason', 'maintenance_mode',
        'message', public.get_setting('maintenance_message') #>> '{}',
        'ends_at', public.get_setting('maintenance_ends_at') #>> '{}',
        'token_version', v_user.token_version
      );
    END IF;
  END IF;

  IF coalesce((public.get_setting('app_locked') #>> '{}')::boolean, false) THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'reason', 'app_locked',
      'message', public.get_setting('app_lock_message') #>> '{}',
      'token_version', v_user.token_version
    );
  END IF;

  RETURN jsonb_build_object(
    'allowed', true,
    'tenant_id', v_user.tenant_id,
    'role', v_user.primary_role,
    'token_version', v_user.token_version
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- AUTHZ-SESSION-BASELINE: every existing public RLS table gets a restrictive
-- authenticated-session requirement. Existing permissive policies still
-- decide the resource-specific authorization; this gate decides whether the
-- session itself is currently valid.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  r record;
  v_policy_name text;
BEGIN
  FOR r IN
    SELECT n.nspname AS schema_name, c.relname AS table_name
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public'
       AND c.relkind IN ('r', 'p')
       AND c.relrowsecurity = true
  LOOP
    v_policy_name := 'auth_session_required_' ||
      substr(md5(r.schema_name || '.' || r.table_name), 1, 16);

    EXECUTE format(
      'DROP POLICY IF EXISTS %I ON %I.%I',
      v_policy_name,
      r.schema_name,
      r.table_name
    );

    EXECUTE format(
      'CREATE POLICY %I ON %I.%I AS RESTRICTIVE FOR ALL TO authenticated USING (public.validate_user_session()) WITH CHECK (public.validate_user_session())',
      v_policy_name,
      r.schema_name,
      r.table_name
    );
  END LOOP;
END
$$;

*** End Patch
