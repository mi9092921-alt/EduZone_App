# EduZone — Feature Flags Database Hardening

هذا الملف يحدد التعديل النهائي المطلوب على مخطط Feature Flags الحالي في `supabase/schema/` فقط. لا ينشئ migrations ولا يضيف ملفات إلى `supabase/schema/`.

## 1. supabase/schema/03_tables.sql

استبدل قسم `RBAC and feature configuration` الخاص بجداول Feature Flags الحالية (`feature_flags`, `tenant_feature_flags`, `feature_flag_roles`, `feature_flag_users`) بهذه التعريفات:

```sql
-- ============================================================================
-- Feature Flags — canonical production data model
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.feature_flags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key text NOT NULL UNIQUE,
  description text,
  is_enabled boolean NOT NULL DEFAULT false,
  rollout_pct smallint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active',
  enabled_from timestamptz,
  enabled_until timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  version bigint NOT NULL DEFAULT 1,
  created_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  updated_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.feature_flags IS
'Global feature-flag definitions. Runtime evaluation is performed by the canonical SECURITY DEFINER evaluator. Client applications do not read this table directly.';
COMMENT ON COLUMN public.feature_flags.rollout_pct IS
'Deterministic rollout percentage in basis points: 0..10000 (10000 = 100%).';
COMMENT ON COLUMN public.feature_flags.is_enabled IS
'Global kill switch. FALSE always disables the flag, regardless of targeting or rollout.';
COMMENT ON COLUMN public.feature_flags.version IS
'Monotonic configuration revision used for cache invalidation and optimistic consistency.';

CREATE TABLE IF NOT EXISTS public.tenant_feature_flags (
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  flag_id uuid NOT NULL REFERENCES public.feature_flags(id) ON DELETE CASCADE,
  is_enabled boolean,
  rollout_pct smallint,
  version bigint NOT NULL DEFAULT 1,
  created_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  updated_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, flag_id)
);

COMMENT ON TABLE public.tenant_feature_flags IS
'Tenant-scoped override of a global feature flag. A row must contain at least one explicit override (enabled state or rollout percentage).';

CREATE TABLE IF NOT EXISTS public.feature_flag_roles (
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  flag_id uuid NOT NULL REFERENCES public.feature_flags(id) ON DELETE CASCADE,
  role_id uuid NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
  is_enabled boolean NOT NULL,
  version bigint NOT NULL DEFAULT 1,
  created_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  updated_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, flag_id, role_id)
);

COMMENT ON TABLE public.feature_flag_roles IS
'Explicit role targeting. FALSE is an explicit deny; TRUE is an explicit allow. The evaluator uses deny-over-allow when a user has multiple matching roles.';

CREATE TABLE IF NOT EXISTS public.feature_flag_users (
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  flag_id uuid NOT NULL REFERENCES public.feature_flags(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  is_enabled boolean NOT NULL,
  version bigint NOT NULL DEFAULT 1,
  created_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  updated_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, flag_id, user_id)
);

COMMENT ON TABLE public.feature_flag_users IS
'Explicit user targeting. A matching user override takes precedence over role targeting and rollout, but never over the global kill switch.';
```

> ملاحظة: بما أن المخطط Development Source-of-Truth، يجب أن يعكس هذا التعريف الملف المرجعي نفسه. لا تستخدم `ALTER TABLE` داخل ملف آخر كحل دائم للموديل.

## 2. supabase/schema/04_constraints.sql

أضف قسم Feature Flags constraints في ملف الـconstraints:

```sql
-- ============================================================================
-- Feature Flags — production invariants
-- ============================================================================

ALTER TABLE public.feature_flags
  ADD CONSTRAINT chk_feature_flags_key_format
  CHECK (
    key = lower(btrim(key))
    AND key ~ '^[a-z][a-z0-9_]*(\\.[a-z0-9_]+)*$'
    AND length(key) BETWEEN 2 AND 128
  );

ALTER TABLE public.feature_flags
  ADD CONSTRAINT chk_feature_flags_description_length
  CHECK (description IS NULL OR length(description) <= 1000);

ALTER TABLE public.feature_flags
  ADD CONSTRAINT chk_feature_flags_rollout_pct
  CHECK (rollout_pct BETWEEN 0 AND 10000);

ALTER TABLE public.feature_flags
  ADD CONSTRAINT chk_feature_flags_status
  CHECK (status IN ('active', 'deprecated', 'archived'));

ALTER TABLE public.feature_flags
  ADD CONSTRAINT chk_feature_flags_schedule
  CHECK (enabled_until IS NULL OR enabled_from IS NULL OR enabled_until > enabled_from);

ALTER TABLE public.feature_flags
  ADD CONSTRAINT chk_feature_flags_metadata_object
  CHECK (jsonb_typeof(metadata) = 'object');

ALTER TABLE public.feature_flags
  ADD CONSTRAINT chk_feature_flags_metadata_size
  CHECK (pg_column_size(metadata) <= 65536);

ALTER TABLE public.feature_flags
  ADD CONSTRAINT chk_feature_flags_version
  CHECK (version >= 1);

ALTER TABLE public.tenant_feature_flags
  ADD CONSTRAINT chk_tenant_feature_flags_override_present
  CHECK (is_enabled IS NOT NULL OR rollout_pct IS NOT NULL);

ALTER TABLE public.tenant_feature_flags
  ADD CONSTRAINT chk_tenant_feature_flags_rollout_pct
  CHECK (rollout_pct IS NULL OR rollout_pct BETWEEN 0 AND 10000);

ALTER TABLE public.tenant_feature_flags
  ADD CONSTRAINT chk_tenant_feature_flags_version
  CHECK (version >= 1);

ALTER TABLE public.feature_flag_roles
  ADD CONSTRAINT chk_feature_flag_roles_version
  CHECK (version >= 1);

ALTER TABLE public.feature_flag_users
  ADD CONSTRAINT chk_feature_flag_users_version
  CHECK (version >= 1);

-- Composite tenant-consistency guarantees. These stop an override row from
-- referring to a role/user belonging to another tenant.
ALTER TABLE public.users
  ADD CONSTRAINT uq_users_tenant_id UNIQUE (tenant_id, id);

ALTER TABLE public.roles
  ADD CONSTRAINT uq_roles_tenant_id UNIQUE (tenant_id, id);

ALTER TABLE public.feature_flag_users
  ADD CONSTRAINT fk_feature_flag_users_tenant_user
  FOREIGN KEY (tenant_id, user_id)
  REFERENCES public.users (tenant_id, id)
  ON DELETE CASCADE;

ALTER TABLE public.feature_flag_roles
  ADD CONSTRAINT fk_feature_flag_roles_tenant_role
  FOREIGN KEY (tenant_id, role_id)
  REFERENCES public.roles (tenant_id, id)
  ON DELETE CASCADE;
```

إذا كانت هذه القيود موجودة مسبقاً في النسخة التي ستُعاد منها عملية البناء، لا تُكررها؛ يجب أن يبقى لكل invariant قيد واحد فقط.

## 3. supabase/schema/05_indexes.sql

أضف:

```sql
-- ============================================================================
-- Feature Flags — runtime and administrative indexes
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_feature_flags_active
  ON public.feature_flags (status, is_enabled, updated_at DESC)
  WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_feature_flags_updated_at
  ON public.feature_flags (updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_tenant_feature_flags_flag_tenant
  ON public.tenant_feature_flags (flag_id, tenant_id);

CREATE INDEX IF NOT EXISTS idx_feature_flag_users_eval
  ON public.feature_flag_users (tenant_id, user_id, flag_id);

CREATE INDEX IF NOT EXISTS idx_feature_flag_users_flag_user
  ON public.feature_flag_users (flag_id, user_id, tenant_id);

CREATE INDEX IF NOT EXISTS idx_feature_flag_roles_eval
  ON public.feature_flag_roles (tenant_id, role_id, flag_id);

CREATE INDEX IF NOT EXISTS idx_feature_flag_roles_flag_role
  ON public.feature_flag_roles (flag_id, role_id, tenant_id);
```

## 4. supabase/schema/06_views.sql

أضف view إدارية آمنة، مع `security_invoker` حتى لا تتجاوز RLS:

```sql
-- ============================================================================
-- Feature Flags — administrative catalog view
-- ============================================================================

CREATE OR REPLACE VIEW public.feature_flags_admin AS
SELECT
  ff.id,
  ff.key,
  ff.description,
  ff.is_enabled,
  ff.rollout_pct,
  ff.status,
  ff.enabled_from,
  ff.enabled_until,
  ff.version,
  ff.created_by,
  ff.updated_by,
  ff.created_at,
  ff.updated_at,
  (
    SELECT count(*)
    FROM public.tenant_feature_flags tff
    WHERE tff.flag_id = ff.id
  ) AS tenant_override_count,
  (
    SELECT count(*)
    FROM public.feature_flag_users ffu
    WHERE ffu.flag_id = ff.id
  ) AS user_override_count,
  (
    SELECT count(*)
    FROM public.feature_flag_roles ffr
    WHERE ffr.flag_id = ff.id
  ) AS role_override_count
FROM public.feature_flags ff;

ALTER VIEW public.feature_flags_admin SET (security_invoker = true);
```

لا تُستخدم هذه view كـruntime evaluator.

## 5. supabase/schema/07_functions.sql

احذف/استبدل evaluator القديم الذي يستخدم `hashtext` و`rollout_pct BETWEEN 0 AND 100`، واستبدله بالكامل بالقسم التالي:

```sql
-- ============================================================================
-- Feature Flags — canonical deterministic evaluation engine
-- ============================================================================

CREATE OR REPLACE FUNCTION public.feature_flag_rollout_bucket(
  p_tenant_id uuid,
  p_user_id uuid,
  p_flag_key text
)
RETURNS integer
LANGUAGE sql
IMMUTABLE
STRICT
SECURITY DEFINER
SET search_path = ''
AS $$
  WITH d AS (
    SELECT extensions.digest(
      pg_catalog.convert_to(
        p_tenant_id::text || ':' || p_user_id::text || ':' || p_flag_key,
        'UTF8'
      ),
      'sha256'
    ) AS h
  )
  SELECT pg_catalog.mod(
    (
      (pg_catalog.get_byte(h, 0)::bigint << 40) |
      (pg_catalog.get_byte(h, 1)::bigint << 32) |
      (pg_catalog.get_byte(h, 2)::bigint << 24) |
      (pg_catalog.get_byte(h, 3)::bigint << 16) |
      (pg_catalog.get_byte(h, 4)::bigint << 8)  |
       pg_catalog.get_byte(h, 5)::bigint
    ),
    10000
  )::integer
  FROM d;
$$;

CREATE OR REPLACE FUNCTION public.evaluate_feature_flag(
  p_key text,
  p_tenant_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_flag public.feature_flags%ROWTYPE;
  v_user public.users%ROWTYPE;
  v_tenant_override public.tenant_feature_flags%ROWTYPE;
  v_user_override boolean;
  v_rollout_pct integer;
  v_bucket integer;
  v_key text := lower(pg_catalog.btrim(p_key));
BEGIN
  IF v_key IS NULL OR v_key = '' OR p_user_id IS NULL THEN
    RETURN false;
  END IF;

  IF auth.role() <> 'service_role' THEN
    IF auth.uid() IS NULL OR p_user_id <> auth.uid() THEN
      RETURN false;
    END IF;

    IF NOT public.validate_user_session() THEN
      RETURN false;
    END IF;
  END IF;

  SELECT u.*
    INTO v_user
  FROM public.users u
  WHERE u.id = p_user_id
    AND u.deleted_at IS NULL
    AND u.account_status = 'active';

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF p_tenant_id IS NULL OR v_user.tenant_id <> p_tenant_id THEN
    RETURN false;
  END IF;

  IF auth.role() <> 'service_role'
     AND p_tenant_id <> public.get_current_tenant_id() THEN
    RETURN false;
  END IF;

  SELECT ff.*
    INTO v_flag
  FROM public.feature_flags ff
  WHERE ff.key = v_key;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  -- Global kill switch is absolute.
  IF v_flag.is_enabled IS FALSE THEN
    RETURN false;
  END IF;

  IF v_flag.status = 'archived' THEN
    RETURN false;
  END IF;

  IF v_flag.enabled_from IS NOT NULL
     AND pg_catalog.now() < v_flag.enabled_from THEN
    RETURN false;
  END IF;

  IF v_flag.enabled_until IS NOT NULL
     AND pg_catalog.now() >= v_flag.enabled_until THEN
    RETURN false;
  END IF;

  -- Tenant override: explicit FALSE is a tenant kill switch; explicit TRUE
  -- allows the tenant to participate in the feature, while its rollout may
  -- still be restricted by rollout_pct.
  SELECT *
    INTO v_tenant_override
  FROM public.tenant_feature_flags tff
  WHERE tff.tenant_id = p_tenant_id
    AND tff.flag_id = v_flag.id;

  IF FOUND THEN
    IF v_tenant_override.is_enabled IS FALSE THEN
      RETURN false;
    END IF;

    v_rollout_pct := coalesce(
      v_tenant_override.rollout_pct,
      v_flag.rollout_pct
    );
  ELSE
    v_rollout_pct := v_flag.rollout_pct;
  END IF;

  -- Explicit user targeting is stronger than role targeting and rollout.
  SELECT ffu.is_enabled
    INTO v_user_override
  FROM public.feature_flag_users ffu
  WHERE ffu.tenant_id = p_tenant_id
    AND ffu.flag_id = v_flag.id
    AND ffu.user_id = p_user_id;

  IF FOUND THEN
    RETURN v_user_override;
  END IF;

  -- Role targeting: explicit deny wins over any allow when a user has multiple
  -- matching roles, preventing ambiguous multi-role evaluations.
  IF EXISTS (
    SELECT 1
    FROM public.feature_flag_roles ffr
    JOIN public.user_roles ur
      ON ur.tenant_id = p_tenant_id
     AND ur.role_id = ffr.role_id
     AND ur.user_id = p_user_id
     AND ur.is_active = true
     AND (ur.expires_at IS NULL OR ur.expires_at > pg_catalog.now())
    WHERE ffr.tenant_id = p_tenant_id
      AND ffr.flag_id = v_flag.id
      AND ffr.is_enabled = false
  ) THEN
    RETURN false;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.feature_flag_roles ffr
    JOIN public.user_roles ur
      ON ur.tenant_id = p_tenant_id
     AND ur.role_id = ffr.role_id
     AND ur.user_id = p_user_id
     AND ur.is_active = true
     AND (ur.expires_at IS NULL OR ur.expires_at > pg_catalog.now())
    WHERE ffr.tenant_id = p_tenant_id
      AND ffr.flag_id = v_flag.id
      AND ffr.is_enabled = true
  ) THEN
    RETURN true;
  END IF;

  v_rollout_pct := greatest(0, least(v_rollout_pct, 10000));

  IF v_rollout_pct = 0 THEN
    RETURN false;
  END IF;

  IF v_rollout_pct = 10000 THEN
    RETURN true;
  END IF;

  v_bucket := public.feature_flag_rollout_bucket(
    p_tenant_id,
    p_user_id,
    v_flag.key
  );

  RETURN v_bucket < v_rollout_pct;
END;
$$;

-- Compatibility-safe wrapper: authenticated callers may evaluate only their own
-- user; service_role may evaluate another user explicitly.
CREATE OR REPLACE FUNCTION public.is_feature_enabled_for_user(
  p_flag_key text,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_tenant_id uuid;
BEGIN
  IF auth.role() <> 'service_role'
     AND p_user_id IS DISTINCT FROM auth.uid() THEN
    RETURN false;
  END IF;

  SELECT u.tenant_id INTO v_tenant_id
  FROM public.users u
  WHERE u.id = p_user_id
    AND u.deleted_at IS NULL
    AND u.account_status = 'active';

  IF v_tenant_id IS NULL THEN
    RETURN false;
  END IF;

  RETURN public.evaluate_feature_flag(
    p_flag_key,
    v_tenant_id,
    p_user_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.is_feature_enabled(
  p_key text,
  p_user_id uuid DEFAULT auth.uid()
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN public.is_feature_enabled_for_user(p_key, p_user_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.evaluate_feature_flags(
  p_keys text[]
)
RETURNS TABLE (
  key text,
  enabled boolean,
  version bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_tenant_id uuid := public.get_current_tenant_id();
BEGIN
  IF v_uid IS NULL OR v_tenant_id IS NULL OR NOT public.validate_user_session() THEN
    RETURN;
  END IF;

  IF p_keys IS NULL OR pg_catalog.cardinality(p_keys) = 0 THEN
    RETURN;
  END IF;

  IF pg_catalog.cardinality(p_keys) > 100 THEN
    RAISE EXCEPTION 'Too many feature flag keys in one evaluation request' USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT
    lower(pg_catalog.btrim(k)) AS key,
    public.evaluate_feature_flag(
      lower(pg_catalog.btrim(k)),
      v_tenant_id,
      v_uid
    ) AS enabled,
    coalesce(ff.version, 0::bigint) AS version
  FROM pg_catalog.unnest(p_keys) AS k
  LEFT JOIN public.feature_flags ff
    ON ff.key = lower(pg_catalog.btrim(k));
END;
$$;

-- Configuration mutation/metadata hardening for all four Feature Flag tables.
CREATE OR REPLACE FUNCTION public.trg_touch_feature_flag_row()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.version := greatest(coalesce(NEW.version, 1), 1);
    NEW.created_at := coalesce(NEW.created_at, pg_catalog.now());
    NEW.updated_at := coalesce(NEW.updated_at, pg_catalog.now());
    NEW.created_by := coalesce(NEW.created_by, auth.uid());
    NEW.updated_by := coalesce(NEW.updated_by, auth.uid());
    RETURN NEW;
  END IF;

  NEW.version := OLD.version + 1;
  NEW.updated_at := pg_catalog.now();
  NEW.updated_by := coalesce(auth.uid(), NEW.updated_by, OLD.updated_by);
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_audit_feature_flag_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_flag_id uuid;
  v_key text;
  v_tenant_id uuid;
  v_before jsonb;
  v_after jsonb;
BEGIN
  v_flag_id := CASE
    WHEN TG_TABLE_NAME = 'feature_flags' THEN coalesce(NEW.id, OLD.id)
    ELSE coalesce(NEW.flag_id, OLD.flag_id)
  END;

  v_tenant_id := CASE
    WHEN TG_TABLE_NAME = 'feature_flags' THEN public.system_tenant_id()
    ELSE coalesce(NEW.tenant_id, OLD.tenant_id, public.system_tenant_id())
  END;

  SELECT ff.key INTO v_key
    FROM public.feature_flags ff
   WHERE ff.id = v_flag_id;

  v_before := CASE
    WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD)
    ELSE NULL
  END;
  v_after := CASE
    WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW)
    ELSE NULL
  END;

  PERFORM public.log_activity_async(
    auth.uid(),
    CASE TG_OP
      WHEN 'INSERT' THEN 'feature_flag_created'
      WHEN 'UPDATE' THEN 'feature_flag_updated'
      WHEN 'DELETE' THEN 'feature_flag_deleted'
    END,
    jsonb_build_object(
      'feature_flag_id', v_flag_id,
      'key', v_key,
      'tenant_id', v_tenant_id,
      'table', TG_TABLE_NAME,
      'operation', TG_OP,
      'before', v_before,
      'after', v_after
    ),
    NULL::inet,
    NULL::uuid,
    'high',
    v_tenant_id
  );

  RETURN coalesce(NEW, OLD);
END;
$$;
```

## 6. supabase/schema/08_triggers.sql

أضف triggers للـtouch/version/audit:

```sql
-- ============================================================================
-- Feature Flags — timestamps, revisions, audit trail
-- ============================================================================

DROP TRIGGER IF EXISTS trg_feature_flags_touch ON public.feature_flags;
CREATE TRIGGER trg_feature_flags_touch
BEFORE INSERT OR UPDATE ON public.feature_flags
FOR EACH ROW
EXECUTE FUNCTION public.trg_touch_feature_flag_row();

DROP TRIGGER IF EXISTS trg_tenant_feature_flags_touch ON public.tenant_feature_flags;
CREATE TRIGGER trg_tenant_feature_flags_touch
BEFORE INSERT OR UPDATE ON public.tenant_feature_flags
FOR EACH ROW
EXECUTE FUNCTION public.trg_touch_feature_flag_row();

DROP TRIGGER IF EXISTS trg_feature_flag_users_touch ON public.feature_flag_users;
CREATE TRIGGER trg_feature_flag_users_touch
BEFORE INSERT OR UPDATE ON public.feature_flag_users
FOR EACH ROW
EXECUTE FUNCTION public.trg_touch_feature_flag_row();

DROP TRIGGER IF EXISTS trg_feature_flag_roles_touch ON public.feature_flag_roles;
CREATE TRIGGER trg_feature_flag_roles_touch
BEFORE INSERT OR UPDATE ON public.feature_flag_roles
FOR EACH ROW
EXECUTE FUNCTION public.trg_touch_feature_flag_row();

DROP TRIGGER IF EXISTS trg_feature_flags_audit ON public.feature_flags;
CREATE TRIGGER trg_feature_flags_audit
AFTER INSERT OR UPDATE OR DELETE ON public.feature_flags
FOR EACH ROW
EXECUTE FUNCTION public.trg_audit_feature_flag_change();

DROP TRIGGER IF EXISTS trg_tenant_feature_flags_audit ON public.tenant_feature_flags;
CREATE TRIGGER trg_tenant_feature_flags_audit
AFTER INSERT OR UPDATE OR DELETE ON public.tenant_feature_flags
FOR EACH ROW
EXECUTE FUNCTION public.trg_audit_feature_flag_change();

DROP TRIGGER IF EXISTS trg_feature_flag_users_audit ON public.feature_flag_users;
CREATE TRIGGER trg_feature_flag_users_audit
AFTER INSERT OR UPDATE OR DELETE ON public.feature_flag_users
FOR EACH ROW
EXECUTE FUNCTION public.trg_audit_feature_flag_change();

DROP TRIGGER IF EXISTS trg_feature_flag_roles_audit ON public.feature_flag_roles;
CREATE TRIGGER trg_feature_flag_roles_audit
AFTER INSERT OR UPDATE OR DELETE ON public.feature_flag_roles
FOR EACH ROW
EXECUTE FUNCTION public.trg_audit_feature_flag_change();
```

## 7. supabase/schema/09_rls.sql

هذا القسم مهم جداً لأن الملف الحالي يحتوي سياسات Feature Flags متكررة/متعارضة. أضف في الجزء النهائي من RLS هذا التنظيف الديناميكي ثم السياسات canonical التالية:

```sql
-- ============================================================================
-- Feature Flags — canonical RLS (remove all historical duplicate policies)
-- ============================================================================

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN (
        'feature_flags',
        'tenant_feature_flags',
        'feature_flag_users',
        'feature_flag_roles'
      )
  LOOP
    EXECUTE format(
      'DROP POLICY IF EXISTS %I ON %I.%I',
      r.policyname,
      r.schemaname,
      r.tablename
    );
  END LOOP;
END;
$$;

ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenant_feature_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feature_flag_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feature_flag_roles ENABLE ROW LEVEL SECURITY;

-- Global definitions: only users with the global Feature Flags permission may
-- inspect or modify definitions. Runtime clients use the evaluator RPC instead.
CREATE POLICY feature_flags_manage
ON public.feature_flags
FOR ALL TO authenticated
USING (
  public.user_has_permission(
    (select auth.uid()),
    'feature_flags.manage'::text,
    public.system_tenant_id()
  )
)
WITH CHECK (
  public.user_has_permission(
    (select auth.uid()),
    'feature_flags.manage'::text,
    public.system_tenant_id()
  )
);

-- Tenant overrides and targeting may be managed by either a global Feature Flag
-- administrator or a tenant-scoped feature flag manager for that tenant.
CREATE POLICY tenant_feature_flags_manage
ON public.tenant_feature_flags
FOR ALL TO authenticated
USING (
  public.user_has_permission(
    (select auth.uid()),
    'feature_flags.manage'::text,
    public.system_tenant_id()
  )
  OR public.user_has_permission(
    (select auth.uid()),
    'feature_flags.tenant_manage'::text,
    tenant_id
  )
)
WITH CHECK (
  public.user_has_permission(
    (select auth.uid()),
    'feature_flags.manage'::text,
    public.system_tenant_id()
  )
  OR public.user_has_permission(
    (select auth.uid()),
    'feature_flags.tenant_manage'::text,
    tenant_id
  )
);

CREATE POLICY feature_flag_users_manage
ON public.feature_flag_users
FOR ALL TO authenticated
USING (
  public.user_has_permission(
    (select auth.uid()),
    'feature_flags.manage'::text,
    public.system_tenant_id()
  )
  OR public.user_has_permission(
    (select auth.uid()),
    'feature_flags.tenant_manage'::text,
    tenant_id
  )
)
WITH CHECK (
  public.user_has_permission(
    (select auth.uid()),
    'feature_flags.manage'::text,
    public.system_tenant_id()
  )
  OR public.user_has_permission(
    (select auth.uid()),
    'feature_flags.tenant_manage'::text,
    tenant_id
  )
);

CREATE POLICY feature_flag_roles_manage
ON public.feature_flag_roles
FOR ALL TO authenticated
USING (
  public.user_has_permission(
    (select auth.uid()),
    'feature_flags.manage'::text,
    public.system_tenant_id()
  )
  OR public.user_has_permission(
    (select auth.uid()),
    'feature_flags.tenant_manage'::text,
    tenant_id
  )
)
WITH CHECK (
  public.user_has_permission(
    (select auth.uid()),
    'feature_flags.manage'::text,
    public.system_tenant_id()
  )
  OR public.user_has_permission(
    (select auth.uid()),
    'feature_flags.tenant_manage'::text,
    tenant_id
  )
);
```

لا تضف policies عامة للطلاب/المستخدمين على هذه الجداول. الـruntime path هو evaluator RPC.

## 8. supabase/schema/10_permissions.sql

استبدل أي grants قديمة واسعة على Feature Flags بالحد الأدنى التالي:

```sql
-- ============================================================================
-- Feature Flags — least-privilege grants
-- ============================================================================

REVOKE ALL ON TABLE public.feature_flags FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.tenant_feature_flags FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.feature_flag_users FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.feature_flag_roles FROM PUBLIC, anon, authenticated;

-- RLS remains the authorization boundary for authenticated administrative access.
GRANT SELECT, INSERT, UPDATE, DELETE
ON public.feature_flags
TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE
ON public.tenant_feature_flags
TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE
ON public.feature_flag_users
TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE
ON public.feature_flag_roles
TO authenticated;

GRANT ALL ON TABLE public.feature_flags,
               public.tenant_feature_flags,
               public.feature_flag_users,
               public.feature_flag_roles
TO service_role;

REVOKE ALL ON FUNCTION public.feature_flag_rollout_bucket(uuid, uuid, text)
FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.evaluate_feature_flag(text, uuid, uuid)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.evaluate_feature_flag(text, uuid, uuid)
TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.evaluate_feature_flags(text[])
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.evaluate_feature_flags(text[])
TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.is_feature_enabled(text, uuid)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_feature_enabled(text, uuid)
TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.is_feature_enabled_for_user(text, uuid)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_feature_enabled_for_user(text, uuid)
TO authenticated, service_role;

GRANT SELECT ON public.feature_flags_admin TO authenticated;
```

## 9. supabase/schema/11_seed_reference.sql

عدّل permission bootstrap بحيث يكون `feature_flags.manage` Global للسوبر أدمن فقط، ويُضاف permission منفصل لإدارة tenant overrides.

في قائمة `permissions` أضف:

```sql
('feature_flags.tenant_manage', 'features', 'tenant_manage', 'tenant', now()),
```

وفي قسم Admin role استبدل:

```sql
AND p.name <> 'tenants.manage'
```

بـ:

```sql
AND p.name NOT IN ('tenants.manage', 'feature_flags.manage')
```

ثم أضف بعد mapping الخاص بالـAdmin:

```sql
-- Tenant admins may manage tenant-scoped overrides only; they never receive
-- the global feature_flags.manage permission.
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
JOIN public.permissions p
  ON p.name = 'feature_flags.tenant_manage'
WHERE r.tenant_id = '00000000-0000-0000-0000-000000000001'
  AND r.name = 'admin'
ON CONFLICT DO NOTHING;

-- Defensive cleanup in case a previous seed granted global Feature Flag
-- management to the admin role.
DELETE FROM public.role_permissions rp
USING public.roles r, public.permissions p
WHERE rp.role_id = r.id
  AND rp.permission_id = p.id
  AND r.tenant_id = '00000000-0000-0000-0000-000000000001'
  AND r.name = 'admin'
  AND p.name = 'feature_flags.manage';
```

لا تزرع product-specific flags في هذه المرحلة إلا بعد تثبيت الـkeys في طبقة Flutter. بنية قاعدة البيانات تكون جاهزة بدون تفعيل أي feature فعلياً.

## 10. supabase/schema/VALIDATION.sql

أضف مجموعة validation مخصصة لـFeature Flags:

```sql
-- ============================================================================
-- Feature Flags — production readiness validation
-- ============================================================================

DO $$
DECLARE
  v_ok boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'feature_flags'
  )
  AND EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'tenant_feature_flags'
  )
  AND EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'feature_flag_users'
  )
  AND EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'feature_flag_roles'
  )
  INTO v_ok;

  INSERT INTO validation_results VALUES (
    'Feature Flag Core Tables Exist',
    CASE WHEN v_ok THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN v_ok THEN 'All Feature Flag tables exist' ELSE 'Feature Flag tables are incomplete' END
  );
END $$;

DO $$
DECLARE
  v_ok boolean;
BEGIN
  SELECT
    EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_feature_flags_rollout_pct')
    AND EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_feature_flags_status')
    AND EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_feature_flags_key_format')
    AND EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_tenant_feature_flags_override_present')
    AND EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_feature_flag_users_tenant_user')
    AND EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_feature_flag_roles_tenant_role')
  INTO v_ok;

  INSERT INTO validation_results VALUES (
    'Feature Flag Constraints',
    CASE WHEN v_ok THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN v_ok THEN 'Core rollout/status/tenant invariants are present' ELSE 'Feature Flag constraints are incomplete' END
  );
END $$;

DO $$
DECLARE
  v_ok boolean;
BEGIN
  SELECT
    c1.relrowsecurity
    AND c2.relrowsecurity
    AND c3.relrowsecurity
    AND c4.relrowsecurity
  INTO v_ok
  FROM pg_class c1
  JOIN pg_namespace n1 ON n1.oid = c1.relnamespace
  JOIN pg_class c2 ON c2.relname = 'tenant_feature_flags'
  JOIN pg_class c3 ON c3.relname = 'feature_flag_users'
  JOIN pg_class c4 ON c4.relname = 'feature_flag_roles'
  WHERE n1.nspname = 'public'
    AND c1.relname = 'feature_flags';

  INSERT INTO validation_results VALUES (
    'Feature Flag RLS Enabled',
    CASE WHEN v_ok THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN v_ok THEN 'RLS is enabled on all Feature Flag tables' ELSE 'Feature Flag RLS is incomplete' END
  );
END $$;

DO $$
DECLARE
  v_bad integer;
BEGIN
  SELECT count(*) INTO v_bad
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename IN ('feature_flags','tenant_feature_flags','feature_flag_users','feature_flag_roles')
    AND policyname IN (
      'feature_flags_select',
      'feature_flags_admin_all',
      'feature_flags_admin_insert',
      'feature_flags_admin_update',
      'feature_flags_admin_delete',
      'tenant_feature_flags_select',
      'tenant_feature_flags_manage'
    );

  INSERT INTO validation_results VALUES (
    'No Historical Feature Flag RLS Duplicates',
    CASE WHEN v_bad = 0 THEN 'PASS' ELSE 'FAIL' END,
    CASE WHEN v_bad = 0 THEN 'Historical permissive policy names are gone' ELSE 'Old Feature Flag policy definitions remain' END
  );
END $$;

DO $$
DECLARE
  v_hashtext boolean;
  v_wrapper boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'evaluate_feature_flag'
      AND pg_get_functiondef(p.oid) ILIKE '%hashtext%'
  ) INTO v_hashtext;

  SELECT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'is_feature_enabled'
      AND pg_get_functiondef(p.oid) ILIKE '%is_feature_enabled_for_user%'
  ) INTO v_wrapper;

  INSERT INTO validation_results VALUES (
    'Canonical Feature Flag Evaluator',
    CASE WHEN NOT v_hashtext AND v_wrapper THEN 'PASS' ELSE 'FAIL' END,
    CASE
      WHEN NOT v_hashtext AND v_wrapper
        THEN 'Single canonical evaluator uses the deterministic bucket helper'
      ELSE 'Legacy evaluator semantics remain active'
    END
  );
END $$;

DO $$
DECLARE
  v_d1 integer;
  v_d2 integer;
BEGIN
  v_d1 := public.feature_flag_rollout_bucket(
    '00000000-0000-0000-0000-000000000001'::uuid,
    'aaaaaaaa-0000-0000-0000-000000000004'::uuid,
    'new_video_player'
  );
  v_d2 := public.feature_flag_rollout_bucket(
    '00000000-0000-0000-0000-000000000001'::uuid,
    'aaaaaaaa-0000-0000-0000-000000000004'::uuid,
    'new_video_player'
  );

  INSERT INTO validation_results VALUES (
    'Deterministic Rollout Bucket',
    CASE WHEN v_d1 = v_d2 AND v_d1 BETWEEN 0 AND 9999 THEN 'PASS' ELSE 'FAIL' END,
    format('bucket_1=%s, bucket_2=%s', v_d1, v_d2)
  );
END $$;

DO $$
DECLARE
  v_global_manage integer;
  v_tenant_manage integer;
BEGIN
  SELECT count(*) INTO v_global_manage
  FROM public.role_permissions rp
  JOIN public.roles r ON r.id = rp.role_id
  JOIN public.permissions p ON p.id = rp.permission_id
  WHERE r.name = 'admin'
    AND p.name = 'feature_flags.manage';

  SELECT count(*) INTO v_tenant_manage
  FROM public.role_permissions rp
  JOIN public.roles r ON r.id = rp.role_id
  JOIN public.permissions p ON p.id = rp.permission_id
  WHERE r.name = 'admin'
    AND p.name = 'feature_flags.tenant_manage';

  INSERT INTO validation_results VALUES (
    'Feature Flag Role Separation',
    CASE WHEN v_global_manage = 0 AND v_tenant_manage > 0 THEN 'PASS' ELSE 'FAIL' END,
    format('admin_global_manage=%s, admin_tenant_manage=%s', v_global_manage, v_tenant_manage)
  );
END $$;

DO $$
DECLARE
  v_auth_eval boolean;
  v_anon_eval boolean;
  v_auth_tables boolean;
  v_anon_tables boolean;
BEGIN
  SELECT has_function_privilege(
    'authenticated',
    'public.evaluate_feature_flags(text[])',
    'EXECUTE'
  ) INTO v_auth_eval;

  SELECT has_function_privilege(
    'anon',
    'public.evaluate_feature_flags(text[])',
    'EXECUTE'
  ) INTO v_anon_eval;

  SELECT has_table_privilege('authenticated', 'public.feature_flags', 'SELECT')
      AND has_table_privilege('authenticated', 'public.tenant_feature_flags', 'UPDATE')
    INTO v_auth_tables;

  SELECT has_table_privilege('anon', 'public.feature_flags', 'SELECT')
      OR has_table_privilege('anon', 'public.tenant_feature_flags', 'SELECT')
    INTO v_anon_tables;

  INSERT INTO validation_results VALUES (
    'Feature Flag Permissions',
    CASE WHEN v_auth_eval AND NOT v_anon_eval AND v_auth_tables AND NOT v_anon_tables THEN 'PASS' ELSE 'FAIL' END,
    format(
      'authenticated_eval=%s, anon_eval=%s, authenticated_table_privileges=%s, anon_table_privileges=%s',
      v_auth_eval, v_anon_eval, v_auth_tables, v_anon_tables
    )
  );
END $$;
```

## النتيجة المعمارية بعد التطبيق

- `feature_flags` = global canonical configuration.
- `is_enabled = false` = absolute global kill switch.
- rollout = 0..10000، deterministic بواسطة `tenant_id + user_id + key`.
- tenant override يمكنه إيقاف tenant بالكامل أو تقليل rollout.
- user override أعلى من role/rollout.
- role deny أعلى من role allow عند تعدد الأدوار.
- archived = دائماً OFF.
- runtime evaluation لا يعتمد على قيم يرسلها العميل لانتحال user/tenant.
- لا يوجد direct runtime read للطلاب على جداول configuration.
- كل mutation له version + timestamps + audit event.
- old duplicate RLS policies تُزال من الجداول الأربعة قبل إنشاء السياسات canonical.
- لا توجد migrations ولا ملفات جديدة داخل `supabase/schema/`.
