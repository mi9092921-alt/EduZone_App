-- AUTO-GENERATED FROM CANONICAL SOURCE
-- Source of truth: ../../Eduzone_schema_v13.sql
-- Normalization pass #3 ownership rules applied.

ALTER TABLE public.security_incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.security_incidents FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS security_incidents_insert ON public.security_incidents;
CREATE POLICY security_incidents_insert ON public.security_incidents
  FOR INSERT TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

DROP POLICY IF EXISTS security_incidents_admin_select ON public.security_incidents;
CREATE POLICY security_incidents_admin_select ON public.security_incidents
  FOR SELECT TO authenticated
  USING (public.is_admin_with_session_validation());

ALTER TABLE public.setting_definitions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS setting_definitions_admin_all ON public.setting_definitions;

CREATE POLICY setting_definitions_admin_all ON public.setting_definitions
  FOR ALL TO authenticated
  USING (public.is_admin_with_session_validation())
  WITH CHECK (public.is_admin_with_session_validation());

-- CRIT-02 FIX: Enable RLS on tenants.
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.tenants FORCE ROW LEVEL SECURITY;

-- Own-tenant read
DROP POLICY IF EXISTS tenants_own_select ON public.tenants;

CREATE POLICY tenants_own_select ON public.tenants
  FOR SELECT TO authenticated
  USING (id = public.get_current_tenant_id());

-- Super-admin read-all
DROP POLICY IF EXISTS tenants_superadmin_select ON public.tenants;

CREATE POLICY tenants_superadmin_select ON public.tenants
  FOR SELECT TO authenticated
  USING (public.is_current_user_super_admin_lite());

-- Super-admin full write
DROP POLICY IF EXISTS tenants_superadmin_all ON public.tenants;

CREATE POLICY tenants_superadmin_all ON public.tenants
  FOR ALL TO authenticated
  USING (public.is_admin_with_session_validation())
  WITH CHECK (public.is_admin_with_session_validation());

-- Anon: no access
DROP POLICY IF EXISTS tenants_anon_deny ON public.tenants;

CREATE POLICY tenants_anon_deny ON public.tenants
  FOR SELECT TO anon USING (false);

-- admins_legacy table removed (fully migrated to RBAC via public.user_roles).

-- CRIT-01 FIX: Integrated RLS policies for users
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.users FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS users_select_policy ON public.users;

CREATE POLICY users_select_policy ON public.users
  FOR SELECT TO authenticated
  USING (
    deleted_at IS NULL
    AND (
      public.is_admin_with_session_validation()
      OR id = (select auth.uid())
      OR (
        tenant_id = public.get_current_tenant_id()
        AND EXISTS (
          SELECT 1
          FROM public.courses c
          JOIN public.enrollments e ON e.course_id = c.id
          WHERE c.teacher_id = (select auth.uid())
            AND e.user_id = users.id
            AND c.tenant_id = public.get_current_tenant_id()
            AND e.status = 'active'
        )
      )
    )
  );

DROP POLICY IF EXISTS users_update_policy ON public.users;

CREATE POLICY users_update_policy ON public.users
  FOR UPDATE
  USING (
    public.validate_user_session()
    AND (
      id = (select auth.uid())
      OR public.is_admin_with_session_validation()
    )
  );

DROP POLICY IF EXISTS users_delete_policy ON public.users;

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.user_roles FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_roles_select_policy ON public.user_roles;

CREATE POLICY user_roles_select_policy ON public.user_roles
  FOR SELECT TO authenticated
  USING (
    public.validate_user_session()
    AND (
      user_id = (select auth.uid())
      OR public.is_admin_with_session_validation()
    )
  );

DROP POLICY IF EXISTS user_roles_admin_all ON public.user_roles;

ALTER TABLE public.tenant_settings ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.security_settings ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.tenant_feature_flags ENABLE ROW LEVEL SECURITY;

-- RLS: only admins and service_role can write; tenants read their own overrides
DROP POLICY IF EXISTS tenant_settings_select ON public.tenant_settings;

CREATE POLICY tenant_settings_select ON public.tenant_settings
  FOR SELECT TO authenticated USING (tenant_id = public.get_current_tenant_id());

DROP POLICY IF EXISTS tenant_settings_admin_all ON public.tenant_settings;

CREATE POLICY tenant_settings_admin_all ON public.tenant_settings
  FOR ALL TO authenticated
  USING (public.is_admin_with_session_validation())
  WITH CHECK (public.is_admin_with_session_validation());

DROP POLICY IF EXISTS security_settings_admin_all ON public.security_settings;

CREATE POLICY security_settings_admin_all ON public.security_settings
  FOR ALL TO authenticated
  USING (public.user_has_permission((select auth.uid()), 'settings.write'::text, public.get_current_tenant_id()))
  WITH CHECK (
    tenant_id = public.assert_tenant()
    AND public.user_has_permission((select auth.uid()), 'settings.write'::text, public.get_current_tenant_id())
  );

ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.courses FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS courses_select_policy ON public.courses;

CREATE POLICY courses_select_policy ON public.courses
  FOR SELECT
  USING (
    deleted_at IS NULL
    AND (
      status = 'published'
      OR (
        public.validate_user_session()
        AND tenant_id = public.get_current_tenant_id()
        AND (
          public.is_admin_with_session_validation()
          OR teacher_id = (select auth.uid())
          OR public.has_course_access(id)
          OR public.user_has_permission(
            public.get_auth_user_id(),
            'courses.read'::text,
            tenant_id
          )
        )
      )
    )
  );

DROP POLICY IF EXISTS courses_admin_all ON public.courses;

CREATE POLICY courses_admin_all ON public.courses
  FOR ALL TO authenticated
  USING (
    public.is_admin_with_session_validation()
    AND deleted_at IS NULL
  )
  WITH CHECK (
    public.is_admin_with_session_validation()
    AND deleted_at IS NULL
  );

ALTER TABLE public.enrollments ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.enrollments FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS enrollments_select_policy ON public.enrollments;

CREATE POLICY enrollments_select_policy ON public.enrollments
  FOR SELECT TO authenticated
  USING (
    deleted_at IS NULL
    AND tenant_id = public.get_current_tenant_id()
    AND (
      user_id = (select auth.uid())
      OR public.is_admin_with_session_validation()
      OR EXISTS (
        SELECT 1
        FROM public.courses c
        WHERE c.id = enrollments.course_id
          AND c.tenant_id = enrollments.tenant_id
          AND c.teacher_id = (select auth.uid())
      )
    )
  );

DROP POLICY IF EXISTS enrollments_insert_policy ON public.enrollments;

CREATE POLICY enrollments_insert_policy ON public.enrollments
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_admin_with_session_validation()
    AND tenant_id = public.assert_tenant()
    AND deleted_at IS NULL
  );

DROP POLICY IF EXISTS enrollments_update_policy ON public.enrollments;

CREATE POLICY enrollments_update_policy ON public.enrollments
  FOR UPDATE
  USING (
    (user_id = (select auth.uid()) OR public.is_admin_with_session_validation())
    AND deleted_at IS NULL
  );

DROP POLICY IF EXISTS enrollments_delete_policy ON public.enrollments;

CREATE POLICY enrollments_delete_policy ON public.enrollments
  FOR DELETE
  USING (false);

ALTER TABLE public.user_progress ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.user_progress FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_progress_select_policy ON public.user_progress;

CREATE POLICY user_progress_select_policy ON public.user_progress
  FOR SELECT TO authenticated
  USING (
    deleted_at IS NULL
    AND tenant_id = public.get_current_tenant_id()
    AND (
      user_id = (select auth.uid())
      OR public.is_admin_with_session_validation()
      OR EXISTS (
        SELECT 1
        FROM public.courses c
        WHERE c.id = user_progress.course_id
          AND c.tenant_id = user_progress.tenant_id
          AND c.teacher_id = (select auth.uid())
      )
    )
  );

DROP POLICY IF EXISTS user_progress_all_policy ON public.user_progress;

CREATE POLICY user_progress_all_policy ON public.user_progress
  FOR ALL TO authenticated
  USING (
    (user_id = (select auth.uid()) OR public.is_admin_with_session_validation())
    AND deleted_at IS NULL
  )
  WITH CHECK (
    (user_id = (select auth.uid()) OR public.is_admin_with_session_validation())
    AND deleted_at IS NULL
  );

ALTER TABLE public.session_locks ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.active_sessions ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.session_snapshots ENABLE ROW LEVEL SECURITY;

-- CRIT-04 FIX: Use O(1) active_sessions PK lookup.
-- Old IN (SELECT id FROM sessions WHERE user_id=...) forces a full cross-partition
-- scan on the partitioned sessions table and cannot use partition pruning inside RLS.
DROP POLICY IF EXISTS session_snapshots_select ON public.session_snapshots;

CREATE POLICY session_snapshots_select ON public.session_snapshots
  FOR SELECT TO authenticated
  USING (
    tenant_id = public.get_current_tenant_id()
    AND (
      session_id = (
        SELECT session_id FROM public.active_sessions
        WHERE  user_id = (select auth.uid())
        LIMIT  1
      )
      OR public.is_admin_with_session_validation()
    )
  );

ALTER TABLE audit.alert_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS alert_log_select ON audit.alert_log;

CREATE POLICY alert_log_select ON audit.alert_log FOR SELECT
USING (public.is_admin_with_session_validation());

-- CRIT-04: Enable RLS on rate_limits
ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rate_limits_select_policy ON public.rate_limits;

CREATE POLICY rate_limits_select_policy ON public.rate_limits
  FOR SELECT
  USING (
    user_id = (select auth.uid())
    OR public.is_admin_with_session_validation()
  );

DROP POLICY IF EXISTS rate_limits_delete_policy ON public.rate_limits;

CREATE POLICY rate_limits_delete_policy ON public.rate_limits
  FOR DELETE
  USING (false);

ALTER TABLE public.schema_migrations ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.regions ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.user_permission_cache ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.settings_kv ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.settings_cache ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.cache_invalidation_queue ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.feature_flag_roles ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.feature_flag_users ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.course_prerequisites ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.course_learning_objectives ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.sections ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.lessons ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.lesson_contents ENABLE ROW LEVEL SECURITY;

ALTER TABLE private.user_access_cache ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.video_views ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.todos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.todos FORCE ROW LEVEL SECURITY;

ALTER TABLE public.warnings ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.user_location_logs ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.user_last_location ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.activity_log_queue ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.audit_chain_state ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.notification_targets ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.user_notifications ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.access_rules ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.user_access_rules ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.rate_limit_rules ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;

ALTER TABLE audit.lesson_access_log ENABLE ROW LEVEL SECURITY;

ALTER TABLE internal.job_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS regions_select ON public.regions;

CREATE POLICY regions_select ON public.regions
  FOR SELECT TO authenticated
  USING (
    is_active
    AND deleted_at IS NULL
    AND (
      EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = (select auth.uid())
          AND u.deleted_at IS NULL
          AND u.region_id = public.regions.id
      )
      OR public.is_admin_with_session_validation()
    )
  );

DROP POLICY IF EXISTS schema_migrations_admin ON public.schema_migrations;

CREATE POLICY schema_migrations_admin ON public.schema_migrations
  FOR ALL TO authenticated
  USING (public.is_admin_with_session_validation())
  WITH CHECK (public.is_admin_with_session_validation());

DROP POLICY IF EXISTS tenants_select ON public.tenants;

CREATE POLICY tenants_select ON public.tenants
  FOR SELECT TO authenticated
  USING (
    deleted_at IS NULL
    AND (id = public.get_current_tenant_id() OR public.is_admin_with_session_validation())
  );

DROP POLICY IF EXISTS tenants_admin_all ON public.tenants;

CREATE POLICY tenants_admin_all ON public.tenants
  FOR ALL TO authenticated
  USING (public.is_admin_with_session_validation())
  WITH CHECK (public.is_admin_with_session_validation());

DROP POLICY IF EXISTS users_select ON public.users;

CREATE POLICY users_self ON public.users
  FOR SELECT TO authenticated
  USING (id = public.get_auth_user_id() AND deleted_at IS NULL);

CREATE POLICY users_teacher_students ON public.users
  FOR SELECT TO authenticated
  USING (
    users.tenant_id = public.get_current_tenant_id() AND
    EXISTS (
      SELECT 1 FROM public.courses c
      JOIN public.enrollments e ON e.course_id = c.id
      WHERE c.teacher_id = public.get_auth_user_id()
        AND e.user_id = users.id
        AND c.tenant_id = public.get_current_tenant_id()
        AND e.status = 'active'
    )
  );

CREATE POLICY users_admin_select ON public.users
  FOR SELECT TO authenticated
  USING (public.is_admin_with_session_validation());

DROP POLICY IF EXISTS users_update_self ON public.users;

CREATE POLICY users_update_self ON public.users
  FOR UPDATE TO authenticated
  USING (id = (select auth.uid()) AND deleted_at IS NULL)
  WITH CHECK (
    id = (select auth.uid())
    AND tenant_id = public.get_current_tenant_id()
    AND primary_role = (SELECT primary_role FROM public.users WHERE id = (select auth.uid()))
  );

DROP POLICY IF EXISTS users_admin_all ON public.users;

CREATE POLICY users_admin_all ON public.users
  FOR ALL TO authenticated
  USING (public.is_admin_with_session_validation())
  WITH CHECK (
    public.is_admin_with_session_validation()
    AND (tenant_id = public.get_current_tenant_id())
  );

DROP POLICY IF EXISTS roles_select ON public.roles;

CREATE POLICY roles_select ON public.roles
  FOR SELECT TO authenticated
  USING (tenant_id = public.system_tenant_id() OR tenant_id = public.get_current_tenant_id() OR public.is_current_user_super_admin_lite());

DROP POLICY IF EXISTS roles_admin_all ON public.roles;

CREATE POLICY roles_admin_all ON public.roles
  FOR ALL TO authenticated
  USING (public.is_admin_with_session_validation())
  WITH CHECK (public.is_admin_with_session_validation());

DROP POLICY IF EXISTS permissions_select ON public.permissions;

CREATE POLICY permissions_select ON public.permissions
  FOR SELECT TO authenticated
  USING (
    public.is_current_user_admin_lite()
    OR EXISTS (
      SELECT 1
      FROM public.user_permission_cache upc
      WHERE upc.user_id = (select auth.uid())
        AND upc.permission_name = permissions.name
        AND upc.tenant_id = public.get_current_tenant_id()
        AND (upc.expires_at IS NULL OR upc.expires_at > pg_catalog.now())
    )
  );

DROP POLICY IF EXISTS permissions_super_admin_all ON public.permissions;

CREATE POLICY permissions_super_admin_all ON public.permissions
  FOR ALL TO authenticated
  USING (public.is_admin_with_session_validation())
  WITH CHECK (public.is_admin_with_session_validation());

DROP POLICY IF EXISTS role_permissions_select ON public.role_permissions;

CREATE POLICY role_permissions_select ON public.role_permissions
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.roles r
      WHERE r.id = role_id
        AND (r.tenant_id = public.system_tenant_id() OR r.tenant_id = public.get_current_tenant_id() OR public.is_current_user_super_admin_lite())
    )
  );

DROP POLICY IF EXISTS role_permissions_admin_all ON public.role_permissions;

CREATE POLICY role_permissions_admin_all ON public.role_permissions
  FOR ALL TO authenticated
  USING (public.is_admin_with_session_validation())
  WITH CHECK (public.is_admin_with_session_validation());

DROP POLICY IF EXISTS user_roles_select ON public.user_roles;

CREATE POLICY user_roles_select ON public.user_roles
  FOR SELECT TO authenticated
  USING (
    user_id = public.get_auth_user_id()
    OR public.is_admin_with_session_validation()
  );

CREATE POLICY user_roles_admin_all ON public.user_roles
  FOR ALL TO authenticated
  USING (public.is_admin_with_session_validation())
  WITH CHECK (public.is_admin_with_session_validation());

DROP POLICY IF EXISTS settings_select ON public.settings_kv;

DROP POLICY IF EXISTS settings_admin_all ON public.settings_kv;

CREATE POLICY settings_admin_all ON public.settings_kv
  FOR ALL TO authenticated
  USING (public.user_has_permission((select auth.uid()), 'settings.write'::text, public.get_current_tenant_id()))
  WITH CHECK (public.user_has_permission((select auth.uid()), 'settings.write'::text, public.get_current_tenant_id()));

DROP POLICY IF EXISTS settings_cache_select ON public.settings_cache;

CREATE POLICY settings_cache_select ON public.settings_cache
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.settings_kv sk
      WHERE sk.key = settings_cache.key
        AND (sk.is_public OR public.is_admin_with_session_validation())
    )
  );

DROP POLICY IF EXISTS admin_only_all ON public.cache_invalidation_queue;

CREATE POLICY admin_only_all ON public.cache_invalidation_queue
  FOR ALL TO authenticated
  USING (public.is_admin_with_session_validation())
  WITH CHECK (public.is_admin_with_session_validation());

DROP POLICY IF EXISTS feature_flags_select ON public.feature_flags;

CREATE POLICY feature_flags_select ON public.feature_flags
  FOR SELECT TO authenticated
  USING (
    is_enabled
    OR public.user_has_permission((select auth.uid()), 'feature_flags.manage'::text, public.get_current_tenant_id())
  );

DROP POLICY IF EXISTS feature_flags_admin_all ON public.feature_flags;

CREATE POLICY feature_flags_admin_all ON public.feature_flags
  FOR ALL TO authenticated
  USING (public.user_has_permission((select auth.uid()), 'feature_flags.manage'::text, public.get_current_tenant_id()))
  WITH CHECK (public.user_has_permission((select auth.uid()), 'feature_flags.manage'::text, public.get_current_tenant_id()));

DROP POLICY IF EXISTS tenant_feature_flags_select ON public.tenant_feature_flags;

CREATE POLICY tenant_feature_flags_select ON public.tenant_feature_flags
  FOR SELECT TO authenticated
  USING (tenant_id = public.get_current_tenant_id());

DROP POLICY IF EXISTS tenant_feature_flags_manage ON public.tenant_feature_flags;

CREATE POLICY tenant_feature_flags_manage ON public.tenant_feature_flags
  FOR ALL TO authenticated
  USING (
    tenant_id = public.get_current_tenant_id()
    AND public.user_has_permission((select auth.uid()), 'feature_flags.manage'::text, public.get_current_tenant_id())
  )
  WITH CHECK (
    tenant_id = public.get_current_tenant_id()
    AND public.user_has_permission((select auth.uid()), 'feature_flags.manage'::text, public.get_current_tenant_id())
  );

DROP POLICY IF EXISTS feature_flag_roles_select ON public.feature_flag_roles;

CREATE POLICY feature_flag_roles_select ON public.feature_flag_roles
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.roles r
      WHERE r.id = role_id
        AND (r.tenant_id = public.system_tenant_id() OR r.tenant_id = public.get_current_tenant_id())
    )
    OR public.is_admin_with_session_validation()
  );

DROP POLICY IF EXISTS feature_flag_users_select ON public.feature_flag_users;

CREATE POLICY feature_flag_users_select ON public.feature_flag_users
  FOR SELECT TO authenticated
  USING (user_id = (select auth.uid()) OR public.is_admin_with_session_validation());

DROP POLICY IF EXISTS courses_select ON public.courses;

CREATE POLICY courses_select ON public.courses
  FOR SELECT TO authenticated
  USING (
    public.is_admin_with_session_validation()
    OR (
      tenant_id = public.get_current_tenant_id()
      AND deleted_at IS NULL
      AND (
        status = 'published'
        OR teacher_id = public.get_auth_user_id()
        OR public.has_course_access(id)
        OR public.user_has_permission(public.get_auth_user_id(), 'courses.read'::text, tenant_id)
      )
    )
  );

DROP POLICY IF EXISTS courses_admin_teacher_all ON public.courses;

DROP POLICY IF EXISTS courses_teacher_insert ON public.courses;

DROP POLICY IF EXISTS courses_teacher_update ON public.courses;

DROP POLICY IF EXISTS courses_admin_insert ON public.courses;

DROP POLICY IF EXISTS courses_admin_update ON public.courses;

DROP POLICY IF EXISTS courses_admin_delete ON public.courses;

CREATE POLICY courses_teacher_insert ON public.courses
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_user_valid_cached(public.get_auth_user_id(), public.get_current_tenant_id())
    AND tenant_id = public.assert_tenant()
    AND teacher_id = public.get_auth_user_id()
    AND deleted_at IS NULL
  );

CREATE POLICY courses_teacher_update ON public.courses
  FOR UPDATE TO authenticated
  USING (
    public.is_user_valid_cached(public.get_auth_user_id(), public.get_current_tenant_id())
    AND tenant_id = public.get_current_tenant_id()
    AND deleted_at IS NULL
    AND teacher_id = public.get_auth_user_id()
  )
  WITH CHECK (
    public.is_user_valid_cached(public.get_auth_user_id(), public.get_current_tenant_id())
    AND
    tenant_id = public.assert_tenant()
    AND deleted_at IS NULL
    AND teacher_id = public.get_auth_user_id()
  );

CREATE POLICY courses_admin_insert ON public.courses
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_admin_with_session_validation()
    AND tenant_id = public.assert_tenant()
    AND deleted_at IS NULL
  );

CREATE POLICY courses_admin_update ON public.courses
  FOR UPDATE TO authenticated
  USING (
    public.is_admin_with_session_validation()
    AND tenant_id = public.get_current_tenant_id()
  )
  WITH CHECK (
    public.is_admin_with_session_validation()
    AND tenant_id = public.assert_tenant()
  );

CREATE POLICY courses_admin_delete ON public.courses
  FOR DELETE TO authenticated
  USING (
    public.is_admin_with_session_validation()
    AND tenant_id = public.get_current_tenant_id()
  );

-- course_prerequisites: full CRUD for teachers and admins (patch 26 hardening)
DROP POLICY IF EXISTS course_prerequisites_select ON public.course_prerequisites;

DROP POLICY IF EXISTS course_prerequisites_all ON public.course_prerequisites;

CREATE POLICY course_prerequisites_all ON public.course_prerequisites
  FOR ALL TO authenticated
  USING (
    tenant_id = public.get_current_tenant_id()
    AND EXISTS (
      SELECT 1 FROM public.courses c
      WHERE c.id = course_prerequisites.course_id
        AND c.tenant_id = public.get_current_tenant_id()
        AND (c.teacher_id = (select auth.uid()) OR public.is_admin_with_session_validation())
    )
  )
  WITH CHECK (
    tenant_id = public.assert_tenant()
    AND EXISTS (
      SELECT 1 FROM public.courses c
      WHERE c.id = course_prerequisites.course_id
        AND c.tenant_id = public.assert_tenant()
        AND (c.teacher_id = (select auth.uid()) OR public.is_admin_with_session_validation())
    )
  );

-- course_learning_objectives: full CRUD for teachers and admins (patch 26 hardening)
DROP POLICY IF EXISTS course_learning_objectives_select ON public.course_learning_objectives;

DROP POLICY IF EXISTS course_learning_objectives_all ON public.course_learning_objectives;

CREATE POLICY course_learning_objectives_all ON public.course_learning_objectives
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.courses c
      WHERE c.id = course_learning_objectives.course_id
        AND c.tenant_id = public.get_current_tenant_id()
        AND (c.teacher_id = (select auth.uid()) OR public.is_admin_with_session_validation())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.courses c
      WHERE c.id = course_learning_objectives.course_id
        AND c.tenant_id = public.assert_tenant()
        AND (c.teacher_id = (select auth.uid()) OR public.is_admin_with_session_validation())
    )
  );

DROP POLICY IF EXISTS sections_select ON public.sections;

CREATE POLICY sections_select ON public.sections
  FOR SELECT TO authenticated
  USING (
    (tenant_id = public.get_current_tenant_id())
    AND deleted_at IS NULL
    AND (
      is_published 
      OR public.is_admin_with_session_validation()
      OR EXISTS (
        SELECT 1 FROM public.courses c
        WHERE c.id = course_id
          AND (c.teacher_id = (select auth.uid()) OR public.is_admin_with_session_validation())
      )
    )
  );

DROP POLICY IF EXISTS sections_admin_teacher_all ON public.sections;

DROP POLICY IF EXISTS sections_teacher_insert ON public.sections;

DROP POLICY IF EXISTS sections_teacher_update ON public.sections;

DROP POLICY IF EXISTS sections_admin_insert ON public.sections;

DROP POLICY IF EXISTS sections_admin_update ON public.sections;

DROP POLICY IF EXISTS sections_admin_delete ON public.sections;

CREATE POLICY sections_teacher_insert ON public.sections
  FOR INSERT TO authenticated
  WITH CHECK (
    tenant_id = public.assert_tenant()
    AND deleted_at IS NULL
    AND EXISTS (
      SELECT 1
      FROM public.courses c
      WHERE c.id = course_id
        AND c.tenant_id = public.assert_tenant()
        AND c.teacher_id = (select auth.uid())
    )
  );

CREATE POLICY sections_teacher_update ON public.sections
  FOR UPDATE TO authenticated
  USING (
    public.is_user_valid_cached((select auth.uid()), public.get_current_tenant_id())
    AND tenant_id = public.get_current_tenant_id()
    AND deleted_at IS NULL
    AND EXISTS (
      SELECT 1 FROM public.courses c
      WHERE c.id = course_id
        AND c.tenant_id = public.get_current_tenant_id()
        AND c.teacher_id = (select auth.uid())
    )
  )
  WITH CHECK (
    tenant_id = public.assert_tenant()
    AND deleted_at IS NULL
    AND
    EXISTS (
      SELECT 1 FROM public.courses c
      WHERE c.id = course_id
        AND c.tenant_id = public.assert_tenant()
        AND c.teacher_id = (select auth.uid())
    )
  );

CREATE POLICY sections_admin_insert ON public.sections
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_admin_with_session_validation()
    AND tenant_id = public.assert_tenant()
    AND EXISTS (
      SELECT 1 FROM public.courses c
      WHERE c.id = course_id
        AND c.tenant_id = public.assert_tenant()
    )
  );

CREATE POLICY sections_admin_update ON public.sections
  FOR UPDATE TO authenticated
  USING (
    public.is_admin_with_session_validation()
    AND tenant_id = public.get_current_tenant_id()
  )
  WITH CHECK (
    public.is_admin_with_session_validation()
    AND tenant_id = public.assert_tenant()
    AND EXISTS (
      SELECT 1 FROM public.courses c
      WHERE c.id = course_id
        AND c.tenant_id = public.assert_tenant()
    )
  );

CREATE POLICY sections_admin_delete ON public.sections
  FOR DELETE TO authenticated
  USING (
    public.is_admin_with_session_validation()
    AND tenant_id = public.get_current_tenant_id()
    AND EXISTS (
      SELECT 1 FROM public.courses c
      WHERE c.id = course_id
        AND c.tenant_id = public.get_current_tenant_id()
    )
  );

DROP POLICY IF EXISTS lessons_select ON public.lessons;

CREATE POLICY lessons_select ON public.lessons
  FOR SELECT TO authenticated
  USING (
    tenant_id = public.get_current_tenant_id()
    AND (
      -- Admins and course teachers can see all lessons (including soft-deleted and drafts)
      public.is_admin_with_session_validation()
      OR public.is_teacher_of_course((select auth.uid()), course_id)
      -- Others (students/anonymous) can only see active (non-deleted) published/preview lessons
      OR (
        deleted_at IS NULL
        AND (is_published OR is_preview)
      )
    )
  );

DROP POLICY IF EXISTS lessons_admin_teacher_all ON public.lessons;

DROP POLICY IF EXISTS lessons_insert ON public.lessons;

DROP POLICY IF EXISTS lessons_update ON public.lessons;

DROP POLICY IF EXISTS lessons_delete ON public.lessons;

CREATE POLICY lessons_insert ON public.lessons
  FOR INSERT TO authenticated
  WITH CHECK (
    tenant_id = public.assert_tenant()
    AND (
      public.is_admin_with_session_validation()
      OR public.is_teacher_of_course((select auth.uid()), course_id)
    )
  );

CREATE POLICY lessons_update ON public.lessons
  FOR UPDATE TO authenticated
  USING (
    tenant_id = public.get_current_tenant_id()
    AND (
      public.is_admin_with_session_validation()
      OR public.is_teacher_of_course((select auth.uid()), course_id)
    )
  )
  WITH CHECK (
    tenant_id = public.assert_tenant()
    AND (
      public.is_admin_with_session_validation()
      OR public.is_teacher_of_course((select auth.uid()), course_id)
    )
  );

CREATE POLICY lessons_delete ON public.lessons
  FOR DELETE TO authenticated
  USING (
    tenant_id = public.get_current_tenant_id()
    AND (
      public.is_admin_with_session_validation()
      OR public.is_teacher_of_course((select auth.uid()), course_id)
    )
  );

DROP POLICY IF EXISTS lesson_contents_select ON public.lesson_contents;

CREATE POLICY lesson_contents_select ON public.lesson_contents
  FOR SELECT TO authenticated
  USING (
    public.is_user_valid_cached((select auth.uid()), public.get_current_tenant_id())
    AND tenant_id = public.get_current_tenant_id()
    AND (
      EXISTS (
        SELECT 1
        FROM public.lessons l
        WHERE l.id = lesson_id
          AND l.tenant_id = lesson_contents.tenant_id
          AND l.deleted_at IS NULL
          AND l.is_preview
      )
      OR public.has_course_access(lesson_contents.course_id)
      OR EXISTS (
        SELECT 1
        FROM public.courses c
        WHERE c.id = lesson_contents.course_id
          AND c.tenant_id = lesson_contents.tenant_id
          AND c.deleted_at IS NULL
          AND c.teacher_id = (select auth.uid())
      )
      OR public.is_admin_with_session_validation()
    )
  );

DROP POLICY IF EXISTS lesson_contents_admin_teacher_all ON public.lesson_contents;

CREATE POLICY lesson_contents_admin_teacher_all ON public.lesson_contents
  FOR ALL TO authenticated
  USING (
    public.is_user_valid_cached((select auth.uid()), public.get_current_tenant_id())
    AND tenant_id = public.get_current_tenant_id()
    AND EXISTS (
      SELECT 1 FROM public.courses c
      WHERE c.id = lesson_contents.course_id
        AND c.tenant_id = lesson_contents.tenant_id
        AND (c.teacher_id = (select auth.uid()) OR public.is_admin_with_session_validation())
    )
  )
  WITH CHECK (
    tenant_id = public.assert_tenant()
    AND
    EXISTS (
      SELECT 1 FROM public.courses c
      WHERE c.id = lesson_contents.course_id
        AND c.tenant_id = public.assert_tenant()
        AND (c.teacher_id = (select auth.uid()) OR public.is_admin_with_session_validation())
    )
  );

-- RLS Consolidated from Phase 4
DROP POLICY IF EXISTS enrollments_self_all ON public.enrollments;
CREATE POLICY enrollments_self_all ON public.enrollments
  FOR ALL TO authenticated
  USING (user_id = public.get_auth_user_id() AND tenant_id = public.get_current_tenant_id())
  WITH CHECK (user_id = public.get_auth_user_id() AND tenant_id = public.assert_tenant());

DROP POLICY IF EXISTS enrollments_teacher_select ON public.enrollments;
CREATE POLICY enrollments_teacher_select ON public.enrollments
  FOR SELECT TO authenticated
  USING (
    public.is_current_user_teacher()
    AND EXISTS (
      SELECT 1 FROM public.courses c
      WHERE c.id = course_id AND c.teacher_id = public.get_auth_user_id()
    )
  );

DROP POLICY IF EXISTS user_progress_self_all ON public.user_progress;
CREATE POLICY user_progress_self_all ON public.user_progress
  FOR ALL TO authenticated
  USING (user_id = (select auth.uid()) AND tenant_id = public.get_current_tenant_id())
  WITH CHECK (user_id = (select auth.uid()) AND tenant_id = public.assert_tenant());

DROP POLICY IF EXISTS user_access_cache_deny_all ON private.user_access_cache;
CREATE POLICY user_access_cache_deny_all ON private.user_access_cache
  FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);

-- devices & push_tokens: mutation via RPC only
DROP POLICY IF EXISTS devices_select ON public.devices;
CREATE POLICY devices_select ON public.devices
  FOR SELECT TO authenticated
  USING (
    tenant_id = public.get_current_tenant_id()
    AND (user_id = (select auth.uid()) OR public.is_admin_with_session_validation())
  );

DROP POLICY IF EXISTS sessions_access ON public.sessions;
CREATE POLICY sessions_access ON public.sessions
  FOR ALL TO authenticated
  USING (
    tenant_id = public.get_current_tenant_id()
    AND (user_id = (select auth.uid()) OR public.is_admin_with_session_validation())
  )
  WITH CHECK (
    tenant_id = public.assert_tenant()
    AND (user_id = (select auth.uid()) OR public.is_admin_with_session_validation())
  );

DROP POLICY IF EXISTS video_views_access ON public.video_views;

CREATE POLICY video_views_access ON public.video_views
  FOR ALL TO authenticated
  USING (
    tenant_id = public.get_current_tenant_id()
    AND (user_id = (select auth.uid()) OR public.is_admin_with_session_validation())
  )
  WITH CHECK (
    tenant_id = public.assert_tenant()
    AND user_id = (select auth.uid())
  );

-- Canonical source of truth: remove any legacy/duplicate policies left by older deployments.
-- Preserves: auth_session_required_* (auto-generated restrictive baseline) and todos_access (canonical).
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'todos'
      AND policyname NOT LIKE 'auth_session_required_%'
      AND policyname <> 'todos_access'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.todos', r.policyname);
  END LOOP;
END $$;

DROP POLICY IF EXISTS todos_access ON public.todos;

CREATE POLICY todos_access ON public.todos
  FOR ALL TO authenticated
  USING (
    tenant_id = public.get_current_tenant_id()
    AND (user_id = (select auth.uid()) OR public.is_admin_with_session_validation())
  )
  WITH CHECK (
    tenant_id = public.assert_tenant()
    AND user_id = (select auth.uid())
  );

DROP POLICY IF EXISTS warnings_select ON public.warnings;

CREATE POLICY warnings_select ON public.warnings
  FOR SELECT TO authenticated
  USING (
    tenant_id = public.get_current_tenant_id()
    AND (user_id = (select auth.uid()) OR public.is_admin_with_session_validation())
  );

DROP POLICY IF EXISTS warnings_admin_insert ON public.warnings;

CREATE POLICY warnings_admin_insert ON public.warnings
  FOR INSERT TO authenticated
  WITH CHECK (
    tenant_id = public.assert_tenant()
    AND public.is_admin_with_session_validation()
  );

-- devices & push_tokens: mutation via RPC only
DROP POLICY IF EXISTS push_tokens_select ON public.push_tokens;
CREATE POLICY push_tokens_select ON public.push_tokens
  FOR SELECT TO authenticated
  USING (
    tenant_id = public.get_current_tenant_id()
    AND (user_id = (select auth.uid()) OR public.is_admin_with_session_validation())
  );

DROP POLICY IF EXISTS location_logs_insert ON public.user_location_logs;

CREATE POLICY location_logs_insert ON public.user_location_logs
  FOR INSERT TO authenticated
  WITH CHECK (
    tenant_id = public.assert_tenant()
    AND user_id = (select auth.uid())
  );

DROP POLICY IF EXISTS location_logs_select ON public.user_location_logs;

DROP POLICY IF EXISTS last_location_access ON public.user_last_location;

CREATE POLICY last_location_access ON public.user_last_location
  FOR ALL TO authenticated
  USING (
    tenant_id = public.get_current_tenant_id()
    AND (user_id = (select auth.uid()) OR public.is_admin_with_session_validation())
  )
  WITH CHECK (
    tenant_id = public.assert_tenant()
    AND user_id = (select auth.uid())
  );

DROP POLICY IF EXISTS activity_log_queue_deny_all ON public.activity_log_queue;

DROP POLICY IF EXISTS activity_logs_select ON public.activity_logs;

CREATE POLICY activity_logs_select ON public.activity_logs
  FOR SELECT TO authenticated
  USING (
    tenant_id = public.get_current_tenant_id()
    AND (user_id = (select auth.uid()) OR public.user_has_permission((select auth.uid()), 'audit.read'::text, public.get_current_tenant_id()))
  );

DROP POLICY IF EXISTS activity_logs_no_update ON public.activity_logs;

CREATE POLICY activity_logs_no_update ON public.activity_logs
  FOR UPDATE USING (false) WITH CHECK (false);

DROP POLICY IF EXISTS activity_logs_no_delete ON public.activity_logs;

CREATE POLICY activity_logs_no_delete ON public.activity_logs
  FOR DELETE USING (false);

DROP POLICY IF EXISTS audit_chain_admin ON public.audit_chain_state;

CREATE POLICY audit_chain_admin ON public.audit_chain_state
  FOR SELECT TO authenticated
  USING (public.user_has_permission((select auth.uid()), 'audit.read'::text, public.get_current_tenant_id()));

ALTER TABLE public.audit_logs FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS audit_logs_admin_all ON public.audit_logs;

CREATE POLICY audit_logs_admin_all ON public.audit_logs
  FOR ALL TO authenticated
  USING (public.is_admin_with_session_validation())
  WITH CHECK (public.is_admin_with_session_validation());

DROP POLICY IF EXISTS notifications_select ON public.notifications;

CREATE POLICY notifications_select ON public.notifications
  FOR SELECT TO authenticated
  USING (
    tenant_id = public.get_current_tenant_id()
    AND deleted_at IS NULL
    AND (
      target_audience = 'all'
      OR public.is_admin_with_session_validation()
      OR EXISTS (
        SELECT 1 FROM public.notification_targets nt
        WHERE nt.notification_id = notifications.id
          AND nt.user_id = (select auth.uid())
      )
    )
  );

DROP POLICY IF EXISTS notifications_admin_write ON public.notifications;

CREATE POLICY notifications_admin_write ON public.notifications
  FOR ALL TO authenticated
  USING (
    tenant_id = public.get_current_tenant_id()
    AND public.user_has_permission((select auth.uid()), 'notifications.send'::text, tenant_id)
  )
  WITH CHECK (
    tenant_id = public.assert_tenant()
    AND public.user_has_permission((select auth.uid()), 'notifications.send'::text, tenant_id)
  );

DROP POLICY IF EXISTS notification_targets_select ON public.notification_targets;

CREATE POLICY notification_targets_select ON public.notification_targets
  FOR SELECT TO authenticated
  USING (
    public.is_user_valid_cached((select auth.uid()), public.get_current_tenant_id())
    AND (
      user_id = (select auth.uid())
      OR (
        public.is_admin_with_session_validation()
        AND EXISTS (
          SELECT 1 FROM public.users u
          WHERE u.id = notification_targets.user_id
            AND u.tenant_id = public.get_current_tenant_id()
        )
      )
    )
  );

-- user_notifications: only SELECT and UPDATE for authenticated, INSERT via RPC only
DROP POLICY IF EXISTS user_notifications_select ON public.user_notifications;
CREATE POLICY user_notifications_select ON public.user_notifications
  FOR SELECT TO authenticated
  USING (tenant_id = public.get_current_tenant_id() AND user_id = (select auth.uid()));

DROP POLICY IF EXISTS user_notifications_update ON public.user_notifications;
CREATE POLICY user_notifications_update ON public.user_notifications
  FOR UPDATE TO authenticated
  USING (tenant_id = public.get_current_tenant_id() AND user_id = (select auth.uid()))
  WITH CHECK (tenant_id = public.assert_tenant() AND user_id = (select auth.uid()));

DROP POLICY IF EXISTS access_rules_admin ON public.access_rules;

CREATE POLICY access_rules_admin ON public.access_rules
  FOR ALL TO authenticated
  USING (
    public.is_admin_with_session_validation()
    AND (tenant_id = public.get_current_tenant_id())
  )
  WITH CHECK (
    public.is_admin_with_session_validation()
    AND (tenant_id = public.get_current_tenant_id())
  );

DROP POLICY IF EXISTS user_access_rules_admin ON public.user_access_rules;

CREATE POLICY user_access_rules_admin ON public.user_access_rules
  FOR ALL TO authenticated
  USING (
    tenant_id = public.get_current_tenant_id()
    AND public.is_admin_with_session_validation()
  )
  WITH CHECK (
    tenant_id = public.assert_tenant()
    AND public.is_admin_with_session_validation()
  );

DROP POLICY IF EXISTS rate_limit_rules_admin ON public.rate_limit_rules;

CREATE POLICY rate_limit_rules_admin ON public.rate_limit_rules
  FOR ALL TO authenticated
  USING (public.is_admin_with_session_validation())
  WITH CHECK (public.is_admin_with_session_validation());

DROP POLICY IF EXISTS rate_limits_admin ON public.rate_limits;

DROP POLICY IF EXISTS rate_limits_admin_insert ON public.rate_limits;

DROP POLICY IF EXISTS rate_limits_admin_update ON public.rate_limits;

CREATE POLICY rate_limits_admin_insert ON public.rate_limits
  FOR INSERT TO authenticated
  WITH CHECK (
    tenant_id = public.assert_tenant()
    AND public.is_admin_with_session_validation()
  );

CREATE POLICY rate_limits_admin_update ON public.rate_limits
  FOR UPDATE TO authenticated
  USING (
    tenant_id = public.get_current_tenant_id()
    AND public.is_admin_with_session_validation()
  )
  WITH CHECK (
    tenant_id = public.assert_tenant()
    AND public.is_admin_with_session_validation()
  );

DROP POLICY IF EXISTS lesson_access_log_select ON audit.lesson_access_log;

CREATE POLICY lesson_access_log_select ON audit.lesson_access_log
  FOR SELECT TO authenticated
  USING (
    tenant_id = public.get_current_tenant_id()
    AND (user_id = (select auth.uid()) OR public.user_has_permission((select auth.uid()), 'audit.read'::text, public.get_current_tenant_id()))
  );

DROP POLICY IF EXISTS lesson_access_log_insert_deny ON audit.lesson_access_log;

CREATE POLICY lesson_access_log_insert_deny ON audit.lesson_access_log
  FOR INSERT TO authenticated
  WITH CHECK (false);

-- HIGH-06: Add RLS policies for devices and sessions
DROP POLICY IF EXISTS devices_select_policy ON public.devices;

CREATE POLICY devices_select_policy ON public.devices
  FOR SELECT TO authenticated
  USING (
    public.validate_user_session()
    AND (user_id = (select auth.uid()) OR public.is_admin_with_session_validation())
  );

DROP POLICY IF EXISTS sessions_select_policy ON public.sessions;

CREATE POLICY sessions_select_policy ON public.sessions
  FOR SELECT TO authenticated
  USING (
    public.validate_user_session()
    AND (user_id = (select auth.uid()) OR public.is_admin_with_session_validation())
    AND deleted_at IS NULL
  );

-- Deny direct access to public child partitions.
DO $$
DECLARE
  v_table regclass;
BEGIN
  FOR v_table IN
    SELECT inhrelid::regclass
    FROM pg_inherits
    WHERE inhparent IN (
      'public.sessions'::regclass,
      'public.video_views'::regclass,
      'public.user_location_logs'::regclass,
      'public.activity_logs'::regclass,
      'public.session_snapshots'::regclass,
      'audit.lesson_access_log'::regclass,
      'audit.alert_log'::regclass
    )
  LOOP
    EXECUTE format('ALTER TABLE %s ENABLE ROW LEVEL SECURITY', v_table);
    EXECUTE format('DROP POLICY IF EXISTS partition_deny_direct ON %s', v_table);
    EXECUTE format('CREATE POLICY partition_deny_direct ON %s FOR ALL TO authenticated USING (false) WITH CHECK (false)', v_table);
  END LOOP;
END $$;

-- Force RLS on critical tables to prevent service_role bypass without tenant_id
ALTER TABLE public.enrollments FORCE ROW LEVEL SECURITY;

ALTER TABLE public.notifications FORCE ROW LEVEL SECURITY;

ALTER TABLE public.user_notifications FORCE ROW LEVEL SECURITY;

-- Telemetry, logs, and partition-heavy tables keep RLS enabled but are not
-- forced, so service-role workers and maintenance jobs do not silently break.
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.sessions FORCE ROW LEVEL SECURITY;

ALTER TABLE public.devices FORCE ROW LEVEL SECURITY;

ALTER TABLE public.video_views FORCE ROW LEVEL SECURITY;

ALTER TABLE public.user_location_logs FORCE ROW LEVEL SECURITY;

ALTER TABLE public.activity_logs FORCE ROW LEVEL SECURITY;

ALTER TABLE public.activity_log_queue FORCE ROW LEVEL SECURITY;

-- ============================================================================
-- Phase 5: Enterprise Hardening (Validation, API, Audit)
-- ============================================================================

-- CRIT-05: Deny all PostgREST access to internal tables
ALTER TABLE public.activity_log_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY activity_log_queue_deny_all ON public.activity_log_queue
  FOR ALL TO public USING (false) WITH CHECK (false);

DROP POLICY IF EXISTS job_queue_deny_all ON internal.job_queue;

CREATE POLICY job_queue_deny_all ON internal.job_queue
  FOR ALL TO public USING (false) WITH CHECK (false);

-- RLS Coverage for audit and internal tables (CRIT-05)
ALTER TABLE audit.slow_query_log ENABLE ROW LEVEL SECURITY;

ALTER TABLE audit.lesson_state_transitions ENABLE ROW LEVEL SECURITY;

ALTER TABLE audit.pii_access_log ENABLE ROW LEVEL SECURITY;

ALTER TABLE audit.deletion_audit ENABLE ROW LEVEL SECURITY;

ALTER TABLE internal.enrollment_progress_temp ENABLE ROW LEVEL SECURITY;

ALTER TABLE internal.workers ENABLE ROW LEVEL SECURITY;

ALTER TABLE internal.job_progress ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.sessions_future ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.video_views_future ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.user_location_logs_future ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.activity_logs_future ENABLE ROW LEVEL SECURITY;

-- Advisor remediation: RLS policies for tables with RLS enabled but no policy
DROP POLICY IF EXISTS active_sessions_select_own ON public.active_sessions;
CREATE POLICY active_sessions_select_own ON public.active_sessions
  FOR SELECT TO authenticated
  USING (user_id = (select auth.uid()));

DROP POLICY IF EXISTS active_sessions_deny_insert ON public.active_sessions;
DROP POLICY IF EXISTS active_sessions_deny_update ON public.active_sessions;
DROP POLICY IF EXISTS active_sessions_deny_delete ON public.active_sessions;
DROP POLICY IF EXISTS active_sessions_deny_write ON public.active_sessions;

CREATE POLICY active_sessions_deny_insert ON public.active_sessions
  FOR INSERT TO authenticated
  WITH CHECK (false);

CREATE POLICY active_sessions_deny_update ON public.active_sessions
  FOR UPDATE TO authenticated
  USING (false)
  WITH CHECK (false);

CREATE POLICY active_sessions_deny_delete ON public.active_sessions
  FOR DELETE TO authenticated
  USING (false);

DROP POLICY IF EXISTS session_locks_deny_all ON public.session_locks;
CREATE POLICY session_locks_deny_all ON public.session_locks
  FOR ALL TO public
  USING (false)
  WITH CHECK (false);

DROP POLICY IF EXISTS user_permission_cache_select_own ON public.user_permission_cache;
CREATE POLICY user_permission_cache_select_own ON public.user_permission_cache
  FOR SELECT TO authenticated
  USING (
    user_id = (select auth.uid())
    AND tenant_id = public.get_current_tenant_id()
  );

DROP POLICY IF EXISTS user_permission_cache_deny_insert ON public.user_permission_cache;
DROP POLICY IF EXISTS user_permission_cache_deny_update ON public.user_permission_cache;
DROP POLICY IF EXISTS user_permission_cache_deny_delete ON public.user_permission_cache;
DROP POLICY IF EXISTS user_permission_cache_deny_write ON public.user_permission_cache;

CREATE POLICY user_permission_cache_deny_insert ON public.user_permission_cache
  FOR INSERT TO authenticated
  WITH CHECK (false);

CREATE POLICY user_permission_cache_deny_update ON public.user_permission_cache
  FOR UPDATE TO authenticated
  USING (false)
  WITH CHECK (false);

CREATE POLICY user_permission_cache_deny_delete ON public.user_permission_cache
  FOR DELETE TO authenticated
  USING (false);

DROP POLICY IF EXISTS slow_query_log_deny_all ON audit.slow_query_log;
CREATE POLICY slow_query_log_deny_all ON audit.slow_query_log
  FOR ALL TO public USING (false) WITH CHECK (false);

DROP POLICY IF EXISTS lesson_state_transitions_deny_all ON audit.lesson_state_transitions;
CREATE POLICY lesson_state_transitions_deny_all ON audit.lesson_state_transitions
  FOR ALL TO public USING (false) WITH CHECK (false);

DROP POLICY IF EXISTS pii_access_log_deny_all ON audit.pii_access_log;
CREATE POLICY pii_access_log_deny_all ON audit.pii_access_log
  FOR ALL TO public USING (false) WITH CHECK (false);

DROP POLICY IF EXISTS deletion_audit_deny_all ON audit.deletion_audit;
CREATE POLICY deletion_audit_deny_all ON audit.deletion_audit
  FOR ALL TO public USING (false) WITH CHECK (false);

DROP POLICY IF EXISTS enrollment_progress_temp_deny_all ON internal.enrollment_progress_temp;
CREATE POLICY enrollment_progress_temp_deny_all ON internal.enrollment_progress_temp
  FOR ALL TO public USING (false) WITH CHECK (false);

DROP POLICY IF EXISTS job_progress_deny_all ON internal.job_progress;
CREATE POLICY job_progress_deny_all ON internal.job_progress
  FOR ALL TO public USING (false) WITH CHECK (false);

DROP POLICY IF EXISTS workers_deny_all ON internal.workers;
CREATE POLICY workers_deny_all ON internal.workers
  FOR ALL TO public USING (false) WITH CHECK (false);

-- Consolidate overlapping permissive SELECT policies (semantics preserved via OR)
DROP POLICY IF EXISTS courses_select_merged ON public.courses;
CREATE POLICY courses_select_merged ON public.courses
  FOR SELECT TO authenticated
  USING (
    deleted_at IS NULL
    AND tenant_id = public.get_current_tenant_id()
    AND (
      public.is_admin_with_session_validation()
      OR status = 'published'
      OR teacher_id = public.get_auth_user_id()
      OR public.has_course_access(id)
      OR public.user_has_permission(
        public.get_auth_user_id(),
        'courses.read'::text,
        tenant_id
      )
    )
  );

DROP POLICY IF EXISTS courses_select_policy ON public.courses;
DROP POLICY IF EXISTS courses_select ON public.courses;

DROP POLICY IF EXISTS courses_select_policy ON public.courses;
CREATE POLICY courses_select_policy ON public.courses
  FOR SELECT TO anon, authenticated, authenticator, dashboard_user, supabase_privileged_role
  USING (
    status = 'published'
    AND deleted_at IS NULL
  );

DROP POLICY IF EXISTS user_roles_select_merged ON public.user_roles;
CREATE POLICY user_roles_select_merged ON public.user_roles
  FOR SELECT TO authenticated
  USING (
    public.validate_user_session()
    AND (
      user_id = public.get_auth_user_id()
      OR public.is_current_user_super_admin()
      OR (
        tenant_id = public.get_current_tenant_id()
        AND public.is_admin_with_session_validation()
      )
    )
  );

DROP POLICY IF EXISTS user_roles_select_policy ON public.user_roles;
DROP POLICY IF EXISTS user_roles_select ON public.user_roles;

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

DROP POLICY IF EXISTS users_select_policy ON public.users;
DROP POLICY IF EXISTS users_self ON public.users;
DROP POLICY IF EXISTS users_teacher_students ON public.users;
DROP POLICY IF EXISTS users_admin_select ON public.users;

DROP POLICY IF EXISTS tenants_select_merged ON public.tenants;
CREATE POLICY tenants_select_merged ON public.tenants
  FOR SELECT TO authenticated
  USING (
    deleted_at IS NULL
    AND (
      public.is_admin_with_session_validation()
      OR public.is_current_user_super_admin_lite()
      OR id = public.get_current_tenant_id()
    )
  );

DROP POLICY IF EXISTS tenants_own_select ON public.tenants;
DROP POLICY IF EXISTS tenants_superadmin_select ON public.tenants;
DROP POLICY IF EXISTS tenants_select ON public.tenants;

DROP POLICY IF EXISTS courses_insert_merged ON public.courses;
CREATE POLICY courses_insert_merged ON public.courses
  FOR INSERT TO authenticated
  WITH CHECK (
    deleted_at IS NULL
    AND (
      (
        public.is_admin_with_session_validation()
        AND tenant_id = public.assert_tenant()
      )
      OR (
        public.is_user_valid_cached(public.get_auth_user_id(), public.get_current_tenant_id())
        AND tenant_id = public.assert_tenant()
        AND teacher_id = public.get_auth_user_id()
      )
    )
  );

DROP POLICY IF EXISTS courses_update_merged ON public.courses;
CREATE POLICY courses_update_merged ON public.courses
  FOR UPDATE TO authenticated
  USING (
    deleted_at IS NULL
    AND (
      (
        public.is_admin_with_session_validation()
        AND tenant_id = public.get_current_tenant_id()
      )
      OR (
        public.is_user_valid_cached(public.get_auth_user_id(), public.get_current_tenant_id())
        AND tenant_id = public.get_current_tenant_id()
        AND teacher_id = public.get_auth_user_id()
      )
    )
  )
  WITH CHECK (
    deleted_at IS NULL
    AND (
      (
        public.is_admin_with_session_validation()
        AND tenant_id = public.assert_tenant()
      )
      OR (
        public.is_user_valid_cached(public.get_auth_user_id(), public.get_current_tenant_id())
        AND tenant_id = public.assert_tenant()
        AND teacher_id = public.get_auth_user_id()
      )
    )
  );

DROP POLICY IF EXISTS courses_admin_all ON public.courses;
DROP POLICY IF EXISTS courses_admin_insert ON public.courses;
DROP POLICY IF EXISTS courses_teacher_insert ON public.courses;
DROP POLICY IF EXISTS courses_admin_update ON public.courses;
DROP POLICY IF EXISTS courses_teacher_update ON public.courses;

DROP POLICY IF EXISTS internal_job_queue_deny ON internal.job_queue;

DROP POLICY IF EXISTS sections_insert_merged ON public.sections;
CREATE POLICY sections_insert_merged ON public.sections
  FOR INSERT TO authenticated
  WITH CHECK (
    (
      public.is_admin_with_session_validation()
      AND tenant_id = public.assert_tenant()
      AND EXISTS (
        SELECT 1 FROM public.courses c
        WHERE c.id = course_id
          AND c.tenant_id = public.assert_tenant()
      )
    )
    OR (
      tenant_id = public.assert_tenant()
      AND deleted_at IS NULL
      AND EXISTS (
        SELECT 1 FROM public.courses c
        WHERE c.id = course_id
          AND c.tenant_id = public.assert_tenant()
          AND c.teacher_id = (select auth.uid())
      )
    )
  );

DROP POLICY IF EXISTS sections_update_merged ON public.sections;
CREATE POLICY sections_update_merged ON public.sections
  FOR UPDATE TO authenticated
  USING (
    (
      public.is_admin_with_session_validation()
      AND tenant_id = public.get_current_tenant_id()
    )
    OR (
      public.is_user_valid_cached((select auth.uid()), public.get_current_tenant_id())
      AND tenant_id = public.get_current_tenant_id()
      AND deleted_at IS NULL
      AND EXISTS (
        SELECT 1 FROM public.courses c
        WHERE c.id = course_id
          AND c.tenant_id = public.get_current_tenant_id()
          AND c.teacher_id = (select auth.uid())
      )
    )
  )
  WITH CHECK (
    (
      public.is_admin_with_session_validation()
      AND tenant_id = public.assert_tenant()
      AND EXISTS (
        SELECT 1 FROM public.courses c
        WHERE c.id = course_id
          AND c.tenant_id = public.assert_tenant()
      )
    )
    OR (
      tenant_id = public.assert_tenant()
      AND deleted_at IS NULL
      AND EXISTS (
        SELECT 1 FROM public.courses c
        WHERE c.id = course_id
          AND c.tenant_id = public.assert_tenant()
          AND c.teacher_id = (select auth.uid())
      )
    )
  );

DROP POLICY IF EXISTS sections_teacher_insert ON public.sections;
DROP POLICY IF EXISTS sections_admin_insert ON public.sections;
DROP POLICY IF EXISTS sections_teacher_update ON public.sections;
DROP POLICY IF EXISTS sections_admin_update ON public.sections;

DROP POLICY IF EXISTS enrollments_insert_merged ON public.enrollments;
CREATE POLICY enrollments_insert_merged ON public.enrollments
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_admin_with_session_validation()
    AND tenant_id = public.assert_tenant()
    AND deleted_at IS NULL
  );

DROP POLICY IF EXISTS enrollments_update_merged ON public.enrollments;
CREATE POLICY enrollments_update_merged ON public.enrollments
  FOR UPDATE TO authenticated
  USING (
    deleted_at IS NULL
    AND tenant_id = public.get_current_tenant_id()
    AND (
      public.is_admin_with_session_validation()
      OR user_id = (select auth.uid())
    )
  )
  WITH CHECK (
    deleted_at IS NULL
    AND tenant_id = public.assert_tenant()
    AND (
      public.is_admin_with_session_validation()
      OR user_id = (select auth.uid())
    )
  );

DROP POLICY IF EXISTS enrollments_delete_merged ON public.enrollments;
CREATE POLICY enrollments_delete_merged ON public.enrollments
  FOR DELETE TO authenticated
  USING (
    (
      public.is_admin_with_session_validation()
      OR (tenant_id = public.get_current_tenant_id() AND public.is_current_user_admin_lite())
    )
    OR (user_id = public.get_auth_user_id() AND tenant_id = public.get_current_tenant_id())
  );

DROP POLICY IF EXISTS enrollments_admin_all ON public.enrollments;
DROP POLICY IF EXISTS enrollments_insert_policy ON public.enrollments;
DROP POLICY IF EXISTS enrollments_update_policy ON public.enrollments;
DROP POLICY IF EXISTS enrollments_delete_policy ON public.enrollments;
DROP POLICY IF EXISTS enrollments_self_all ON public.enrollments;

DROP POLICY IF EXISTS user_progress_insert_merged ON public.user_progress;
CREATE POLICY user_progress_insert_merged ON public.user_progress
  FOR INSERT TO authenticated
  WITH CHECK (
    deleted_at IS NULL
    AND tenant_id = public.assert_tenant()
    AND (
      public.is_admin_with_session_validation()
      OR user_id = (select auth.uid())
    )
  );

DROP POLICY IF EXISTS user_progress_update_merged ON public.user_progress;
CREATE POLICY user_progress_update_merged ON public.user_progress
  FOR UPDATE TO authenticated
  USING (
    deleted_at IS NULL
    AND tenant_id = public.get_current_tenant_id()
    AND (
      public.is_admin_with_session_validation()
      OR user_id = (select auth.uid())
    )
  )
  WITH CHECK (
    deleted_at IS NULL
    AND tenant_id = public.assert_tenant()
    AND (
      public.is_admin_with_session_validation()
      OR user_id = (select auth.uid())
    )
  );

DROP POLICY IF EXISTS user_progress_delete_merged ON public.user_progress;
CREATE POLICY user_progress_delete_merged ON public.user_progress
  FOR DELETE TO authenticated
  USING (
    deleted_at IS NULL
    AND tenant_id = public.get_current_tenant_id()
    AND (
      public.is_admin_with_session_validation()
      OR user_id = (select auth.uid())
    )
  );

DROP POLICY IF EXISTS user_progress_admin_all ON public.user_progress;
DROP POLICY IF EXISTS user_progress_all_policy ON public.user_progress;
DROP POLICY IF EXISTS user_progress_self_all ON public.user_progress;

DROP POLICY IF EXISTS users_update_merged ON public.users;
CREATE POLICY users_update_merged ON public.users
  FOR UPDATE TO authenticated
  USING (
    public.is_current_user_super_admin()
    OR (
      public.is_admin_with_session_validation()
      AND tenant_id = public.get_current_tenant_id()
    )
    OR (
      public.validate_user_session()
      AND id = (select auth.uid())
      AND deleted_at IS NULL
    )
  )
  WITH CHECK (
    public.is_current_user_super_admin()
    OR (
      public.is_admin_with_session_validation()
      AND tenant_id = public.assert_tenant()
    )
    OR (
      id = (select auth.uid())
      AND tenant_id = public.assert_tenant()
      AND primary_role = (
        SELECT primary_role
        FROM public.users
        WHERE id = (select auth.uid())
      )
    )
  );

DROP POLICY IF EXISTS users_update_policy ON public.users;
DROP POLICY IF EXISTS users_update_self ON public.users;

DROP POLICY IF EXISTS tenants_write_merged ON public.tenants;
CREATE POLICY tenants_write_merged ON public.tenants
  FOR ALL TO authenticated
  USING (public.is_admin_with_session_validation())
  WITH CHECK (public.is_admin_with_session_validation());

DROP POLICY IF EXISTS tenants_admin_all ON public.tenants;
DROP POLICY IF EXISTS tenants_superadmin_all ON public.tenants;

-- -- B. Admin-wide RLS fixes (patches 23, 24) --------------------------------Ã¢â€â‚¬

-- Sessions: admin can see all active sessions
DROP POLICY IF EXISTS sessions_access ON public.sessions;

DROP POLICY IF EXISTS sessions_admin_all ON public.sessions;

CREATE POLICY sessions_admin_all ON public.sessions
  FOR ALL TO authenticated
  USING (
    public.is_admin_with_session_validation()
    OR (tenant_id = public.get_current_tenant_id() AND public.is_current_user_admin_lite())
  );

-- Devices: admin can see all devices
DROP POLICY IF EXISTS devices_select ON public.devices;

DROP POLICY IF EXISTS devices_select_policy ON public.devices;

DROP POLICY IF EXISTS devices_admin_all ON public.devices;

CREATE POLICY devices_admin_all ON public.devices
  FOR ALL TO authenticated
  USING (
    public.is_admin_with_session_validation()
    OR (tenant_id = public.get_current_tenant_id() AND public.is_current_user_admin_lite())
  );

-- Location logs: super admin cross-tenant, admin tenant-scoped
DROP POLICY IF EXISTS location_logs_select ON public.user_location_logs;

CREATE POLICY location_logs_select ON public.user_location_logs
  FOR SELECT TO authenticated
  USING (
    public.is_current_user_super_admin_lite()
    OR (
      tenant_id = public.get_current_tenant_id()
      AND (user_id = (select auth.uid()) OR public.is_current_user_admin_lite())
    )
  );

-- -- C. Settings RLS fix (patch 9) --------------------------------------------
DROP POLICY IF EXISTS settings_kv_deny_all ON public.settings_kv;

CREATE POLICY settings_select ON public.settings_kv
  FOR SELECT TO authenticated, anon
  USING (
    is_public
    OR ((select auth.uid()) IS NOT NULL AND public.user_has_permission((select auth.uid()), 'settings.read'::text, public.get_current_tenant_id()))
  );

-- CRIT: RLS for reference / session-validity tables exposed via API grants
ALTER TABLE public.constants ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.constants FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS constants_authenticated_read ON public.constants;

CREATE POLICY constants_authenticated_read ON public.constants
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS constants_anon_deny ON public.constants;

CREATE POLICY constants_anon_deny ON public.constants
  FOR ALL TO anon
  USING (false);

ALTER TABLE public.user_validity_cache ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.user_validity_cache FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_validity_cache_own_read ON public.user_validity_cache;

CREATE POLICY user_validity_cache_own_read ON public.user_validity_cache
  FOR SELECT TO authenticated
  USING (
    user_id = (select auth.uid())
    AND tenant_id = public.get_current_tenant_id()
  );

DROP POLICY IF EXISTS user_validity_cache_anon_deny ON public.user_validity_cache;

CREATE POLICY user_validity_cache_anon_deny ON public.user_validity_cache
  FOR ALL TO anon
  USING (false);

-- Advisor pass 2: split remaining FOR ALL admin policies (Postgres allows one cmd per policy).
DROP POLICY IF EXISTS enrollments_select_policy ON public.enrollments;
CREATE POLICY enrollments_select_policy ON public.enrollments
  FOR SELECT TO authenticated
  USING (
    deleted_at IS NULL
    AND tenant_id = public.get_current_tenant_id()
    AND (
      user_id = (select auth.uid())
      OR public.is_admin_with_session_validation()
      OR EXISTS (
        SELECT 1
        FROM public.courses c
        WHERE c.id = enrollments.course_id
          AND c.tenant_id = enrollments.tenant_id
          AND c.teacher_id = (select auth.uid())
      )
    )
  );

DROP POLICY IF EXISTS feature_flags_admin_all ON public.feature_flags;
DROP POLICY IF EXISTS feature_flags_admin_insert ON public.feature_flags;
DROP POLICY IF EXISTS feature_flags_admin_update ON public.feature_flags;
DROP POLICY IF EXISTS feature_flags_admin_delete ON public.feature_flags;
CREATE POLICY feature_flags_admin_insert ON public.feature_flags FOR INSERT TO authenticated
  WITH CHECK (public.user_has_permission((select auth.uid()), 'feature_flags.manage'::text, public.get_current_tenant_id()));
CREATE POLICY feature_flags_admin_update ON public.feature_flags FOR UPDATE TO authenticated
  USING (public.user_has_permission((select auth.uid()), 'feature_flags.manage'::text, public.get_current_tenant_id()))
  WITH CHECK (public.user_has_permission((select auth.uid()), 'feature_flags.manage'::text, public.get_current_tenant_id()));
CREATE POLICY feature_flags_admin_delete ON public.feature_flags FOR DELETE TO authenticated
  USING (public.user_has_permission((select auth.uid()), 'feature_flags.manage'::text, public.get_current_tenant_id()));

DROP POLICY IF EXISTS lesson_contents_admin_teacher_all ON public.lesson_contents;
DROP POLICY IF EXISTS lesson_contents_admin_teacher_insert ON public.lesson_contents;
DROP POLICY IF EXISTS lesson_contents_admin_teacher_update ON public.lesson_contents;
DROP POLICY IF EXISTS lesson_contents_admin_teacher_delete ON public.lesson_contents;
CREATE POLICY lesson_contents_admin_teacher_insert ON public.lesson_contents FOR INSERT TO authenticated
  WITH CHECK (
    public.is_user_valid_cached((select auth.uid()), public.get_current_tenant_id())
    AND tenant_id = public.assert_tenant()
    AND EXISTS (
      SELECT 1 FROM public.courses c
      WHERE c.id = lesson_contents.course_id
        AND c.tenant_id = public.assert_tenant()
        AND (c.teacher_id = (select auth.uid()) OR public.is_admin_with_session_validation())
    )
  );
CREATE POLICY lesson_contents_admin_teacher_update ON public.lesson_contents FOR UPDATE TO authenticated
  USING (
    public.is_user_valid_cached((select auth.uid()), public.get_current_tenant_id())
    AND tenant_id = public.get_current_tenant_id()
    AND EXISTS (
      SELECT 1 FROM public.courses c
      WHERE c.id = lesson_contents.course_id
        AND c.tenant_id = lesson_contents.tenant_id
        AND (c.teacher_id = (select auth.uid()) OR public.is_admin_with_session_validation())
    )
  )
  WITH CHECK (
    tenant_id = public.assert_tenant()
    AND EXISTS (
      SELECT 1 FROM public.courses c
      WHERE c.id = lesson_contents.course_id
        AND c.tenant_id = public.assert_tenant()
        AND (c.teacher_id = (select auth.uid()) OR public.is_admin_with_session_validation())
    )
  );
CREATE POLICY lesson_contents_admin_teacher_delete ON public.lesson_contents FOR DELETE TO authenticated
  USING (
    public.is_user_valid_cached((select auth.uid()), public.get_current_tenant_id())
    AND tenant_id = public.get_current_tenant_id()
    AND EXISTS (
      SELECT 1 FROM public.courses c
      WHERE c.id = lesson_contents.course_id
        AND c.tenant_id = lesson_contents.tenant_id
        AND (c.teacher_id = (select auth.uid()) OR public.is_admin_with_session_validation())
    )
  );

DROP POLICY IF EXISTS notifications_admin_write ON public.notifications;
DROP POLICY IF EXISTS notifications_admin_insert ON public.notifications;
DROP POLICY IF EXISTS notifications_admin_update ON public.notifications;
DROP POLICY IF EXISTS notifications_admin_delete ON public.notifications;
CREATE POLICY notifications_admin_insert ON public.notifications FOR INSERT TO authenticated
  WITH CHECK (
    tenant_id = public.assert_tenant()
    AND public.user_has_permission((select auth.uid()), 'notifications.send'::text, tenant_id)
  );
CREATE POLICY notifications_admin_update ON public.notifications FOR UPDATE TO authenticated
  USING (
    tenant_id = public.get_current_tenant_id()
    AND public.user_has_permission((select auth.uid()), 'notifications.send'::text, tenant_id)
  )
  WITH CHECK (
    tenant_id = public.assert_tenant()
    AND public.user_has_permission((select auth.uid()), 'notifications.send'::text, tenant_id)
  );
CREATE POLICY notifications_admin_delete ON public.notifications FOR DELETE TO authenticated
  USING (
    tenant_id = public.get_current_tenant_id()
    AND public.user_has_permission((select auth.uid()), 'notifications.send'::text, tenant_id)
  );

DROP POLICY IF EXISTS permissions_super_admin_all ON public.permissions;
DROP POLICY IF EXISTS permissions_super_admin_insert ON public.permissions;
DROP POLICY IF EXISTS permissions_super_admin_update ON public.permissions;
DROP POLICY IF EXISTS permissions_super_admin_delete ON public.permissions;
CREATE POLICY permissions_super_admin_insert ON public.permissions FOR INSERT TO authenticated
  WITH CHECK (public.is_admin_with_session_validation());
CREATE POLICY permissions_super_admin_update ON public.permissions FOR UPDATE TO authenticated
  USING (public.is_admin_with_session_validation())
  WITH CHECK (public.is_admin_with_session_validation());
CREATE POLICY permissions_super_admin_delete ON public.permissions FOR DELETE TO authenticated
  USING (public.is_admin_with_session_validation());

DROP POLICY IF EXISTS role_permissions_admin_all ON public.role_permissions;
DROP POLICY IF EXISTS role_permissions_admin_insert ON public.role_permissions;
DROP POLICY IF EXISTS role_permissions_admin_update ON public.role_permissions;
DROP POLICY IF EXISTS role_permissions_admin_delete ON public.role_permissions;
CREATE POLICY role_permissions_admin_insert ON public.role_permissions FOR INSERT TO authenticated
  WITH CHECK (
    public.is_current_user_super_admin()
    OR (
      public.is_admin_with_session_validation()
      AND EXISTS (
        SELECT 1
        FROM public.roles r
        WHERE r.id = role_id
          AND r.tenant_id = public.get_current_tenant_id()
      )
    )
  );
CREATE POLICY role_permissions_admin_update ON public.role_permissions FOR UPDATE TO authenticated
  USING (
    public.is_current_user_super_admin()
    OR (
      public.is_admin_with_session_validation()
      AND EXISTS (
        SELECT 1
        FROM public.roles r
        WHERE r.id = role_id
          AND r.tenant_id = public.get_current_tenant_id()
      )
    )
  )
  WITH CHECK (
    public.is_current_user_super_admin()
    OR (
      public.is_admin_with_session_validation()
      AND EXISTS (
        SELECT 1
        FROM public.roles r
        WHERE r.id = role_id
          AND r.tenant_id = public.get_current_tenant_id()
      )
    )
  );
CREATE POLICY role_permissions_admin_delete ON public.role_permissions FOR DELETE TO authenticated
  USING (
    public.is_current_user_super_admin()
    OR (
      public.is_admin_with_session_validation()
      AND EXISTS (
        SELECT 1
        FROM public.roles r
        WHERE r.id = role_id
          AND r.tenant_id = public.get_current_tenant_id()
      )
    )
  );

DROP POLICY IF EXISTS roles_admin_all ON public.roles;
DROP POLICY IF EXISTS roles_admin_insert ON public.roles;
DROP POLICY IF EXISTS roles_admin_update ON public.roles;
DROP POLICY IF EXISTS roles_admin_delete ON public.roles;
CREATE POLICY roles_admin_insert ON public.roles FOR INSERT TO authenticated
  WITH CHECK (
    public.is_current_user_super_admin()
    OR (
      public.is_admin_with_session_validation()
      AND tenant_id = public.assert_tenant()
    )
  );
CREATE POLICY roles_admin_update ON public.roles FOR UPDATE TO authenticated
  USING (
    public.is_current_user_super_admin()
    OR (
      public.is_admin_with_session_validation()
      AND tenant_id = public.get_current_tenant_id()
    )
  )
  WITH CHECK (
    public.is_current_user_super_admin()
    OR (
      public.is_admin_with_session_validation()
      AND tenant_id = public.assert_tenant()
    )
  );
CREATE POLICY roles_admin_delete ON public.roles FOR DELETE TO authenticated
  USING (
    public.is_current_user_super_admin()
    OR (
      public.is_admin_with_session_validation()
      AND tenant_id = public.get_current_tenant_id()
    )
  );

DROP POLICY IF EXISTS settings_admin_all ON public.settings_kv;
DROP POLICY IF EXISTS settings_admin_insert ON public.settings_kv;
DROP POLICY IF EXISTS settings_admin_update ON public.settings_kv;
DROP POLICY IF EXISTS settings_admin_delete ON public.settings_kv;
CREATE POLICY settings_admin_insert ON public.settings_kv FOR INSERT TO authenticated
  WITH CHECK (public.is_current_user_super_admin());
CREATE POLICY settings_admin_update ON public.settings_kv FOR UPDATE TO authenticated
  USING (public.is_current_user_super_admin())
  WITH CHECK (public.is_current_user_super_admin());
CREATE POLICY settings_admin_delete ON public.settings_kv FOR DELETE TO authenticated
  USING (public.is_current_user_super_admin());

DROP POLICY IF EXISTS tenant_feature_flags_manage ON public.tenant_feature_flags;
DROP POLICY IF EXISTS tenant_feature_flags_insert ON public.tenant_feature_flags;
DROP POLICY IF EXISTS tenant_feature_flags_update ON public.tenant_feature_flags;
DROP POLICY IF EXISTS tenant_feature_flags_delete ON public.tenant_feature_flags;
CREATE POLICY tenant_feature_flags_insert ON public.tenant_feature_flags FOR INSERT TO authenticated
  WITH CHECK (
    tenant_id = public.get_current_tenant_id()
    AND public.user_has_permission((select auth.uid()), 'feature_flags.manage'::text, public.get_current_tenant_id())
  );
CREATE POLICY tenant_feature_flags_update ON public.tenant_feature_flags FOR UPDATE TO authenticated
  USING (
    tenant_id = public.get_current_tenant_id()
    AND public.user_has_permission((select auth.uid()), 'feature_flags.manage'::text, public.get_current_tenant_id())
  )
  WITH CHECK (
    tenant_id = public.get_current_tenant_id()
    AND public.user_has_permission((select auth.uid()), 'feature_flags.manage'::text, public.get_current_tenant_id())
  );
CREATE POLICY tenant_feature_flags_delete ON public.tenant_feature_flags FOR DELETE TO authenticated
  USING (
    tenant_id = public.get_current_tenant_id()
    AND public.user_has_permission((select auth.uid()), 'feature_flags.manage'::text, public.get_current_tenant_id())
  );

DROP POLICY IF EXISTS tenant_settings_admin_all ON public.tenant_settings;
DROP POLICY IF EXISTS tenant_settings_admin_insert ON public.tenant_settings;
DROP POLICY IF EXISTS tenant_settings_admin_update ON public.tenant_settings;
DROP POLICY IF EXISTS tenant_settings_admin_delete ON public.tenant_settings;
CREATE POLICY tenant_settings_admin_insert ON public.tenant_settings FOR INSERT TO authenticated
  WITH CHECK (
    public.is_current_user_super_admin()
    OR (
      public.is_admin_with_session_validation()
      AND tenant_id = public.assert_tenant()
    )
  );
CREATE POLICY tenant_settings_admin_update ON public.tenant_settings FOR UPDATE TO authenticated
  USING (
    public.is_current_user_super_admin()
    OR (
      public.is_admin_with_session_validation()
      AND tenant_id = public.get_current_tenant_id()
    )
  )
  WITH CHECK (
    public.is_current_user_super_admin()
    OR (
      public.is_admin_with_session_validation()
      AND tenant_id = public.assert_tenant()
    )
  );
CREATE POLICY tenant_settings_admin_delete ON public.tenant_settings FOR DELETE TO authenticated
  USING (
    public.is_current_user_super_admin()
    OR (
      public.is_admin_with_session_validation()
      AND tenant_id = public.get_current_tenant_id()
    )
  );

DROP POLICY IF EXISTS tenants_write_merged ON public.tenants;
DROP POLICY IF EXISTS tenants_write_insert ON public.tenants;
DROP POLICY IF EXISTS tenants_write_update ON public.tenants;
DROP POLICY IF EXISTS tenants_write_delete ON public.tenants;
CREATE POLICY tenants_write_insert ON public.tenants FOR INSERT TO authenticated
  WITH CHECK (public.is_current_user_super_admin());
CREATE POLICY tenants_write_update ON public.tenants FOR UPDATE TO authenticated
  USING (public.is_current_user_super_admin())
  WITH CHECK (public.is_current_user_super_admin());
CREATE POLICY tenants_write_delete ON public.tenants FOR DELETE TO authenticated
  USING (public.is_current_user_super_admin());

DROP POLICY IF EXISTS user_roles_admin_all ON public.user_roles;
DROP POLICY IF EXISTS user_roles_admin_insert ON public.user_roles;
DROP POLICY IF EXISTS user_roles_admin_update ON public.user_roles;
DROP POLICY IF EXISTS user_roles_admin_delete ON public.user_roles;
CREATE POLICY user_roles_admin_insert ON public.user_roles FOR INSERT TO authenticated
  WITH CHECK (
    public.is_current_user_super_admin()
    OR (
      public.is_admin_with_session_validation()
      AND tenant_id = public.assert_tenant()
      AND EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id = user_id
          AND u.tenant_id = public.get_current_tenant_id()
          AND u.deleted_at IS NULL
      )
      AND EXISTS (
        SELECT 1
        FROM public.roles r
        WHERE r.id = role_id
          AND r.tenant_id = public.get_current_tenant_id()
      )
    )
  );
CREATE POLICY user_roles_admin_update ON public.user_roles FOR UPDATE TO authenticated
  USING (
    public.is_current_user_super_admin()
    OR (
      public.is_admin_with_session_validation()
      AND tenant_id = public.get_current_tenant_id()
    )
  )
  WITH CHECK (
    public.is_current_user_super_admin()
    OR (
      public.is_admin_with_session_validation()
      AND tenant_id = public.assert_tenant()
      AND EXISTS (
        SELECT 1
        FROM public.users u
        WHERE u.id = user_id
          AND u.tenant_id = public.get_current_tenant_id()
          AND u.deleted_at IS NULL
      )
      AND EXISTS (
        SELECT 1
        FROM public.roles r
        WHERE r.id = role_id
          AND r.tenant_id = public.get_current_tenant_id()
      )
    )
  );
CREATE POLICY user_roles_admin_delete ON public.user_roles FOR DELETE TO authenticated
  USING (
    public.is_current_user_super_admin()
    OR (
      public.is_admin_with_session_validation()
      AND tenant_id = public.get_current_tenant_id()
    )
  );

DROP POLICY IF EXISTS users_admin_all ON public.users;
DROP POLICY IF EXISTS users_admin_insert ON public.users;
DROP POLICY IF EXISTS users_admin_update ON public.users;
DROP POLICY IF EXISTS users_admin_delete ON public.users;
CREATE POLICY users_admin_insert ON public.users FOR INSERT TO authenticated
  WITH CHECK (
    public.is_current_user_super_admin()
    OR (
      public.is_admin_with_session_validation()
      AND tenant_id = public.assert_tenant()
    )
  );
CREATE POLICY users_admin_delete ON public.users FOR DELETE TO authenticated
  USING (
    public.is_current_user_super_admin()
    OR (
      public.is_admin_with_session_validation()
      AND tenant_id = public.get_current_tenant_id()
    )
  );

DROP POLICY IF EXISTS users_delete_policy ON public.users;

-- AUTHZ-TENANT-01: privileged mutation must respect the row's tenant unless
-- the caller is an actual super_admin. Admin status alone is never a
-- cross-tenant authorization boundary.
DROP POLICY IF EXISTS permissions_super_admin_all ON public.permissions;
DROP POLICY IF EXISTS permissions_super_admin_insert ON public.permissions;
DROP POLICY IF EXISTS permissions_super_admin_update ON public.permissions;
DROP POLICY IF EXISTS permissions_super_admin_delete ON public.permissions;
CREATE POLICY permissions_super_admin_insert ON public.permissions FOR INSERT TO authenticated
  WITH CHECK (public.is_current_user_super_admin());
CREATE POLICY permissions_super_admin_update ON public.permissions FOR UPDATE TO authenticated
  USING (public.is_current_user_super_admin())
  WITH CHECK (public.is_current_user_super_admin());
CREATE POLICY permissions_super_admin_delete ON public.permissions FOR DELETE TO authenticated
  USING (public.is_current_user_super_admin());

DROP POLICY IF EXISTS feature_flags_admin_all ON public.feature_flags;
DROP POLICY IF EXISTS feature_flags_admin_insert ON public.feature_flags;
DROP POLICY IF EXISTS feature_flags_admin_update ON public.feature_flags;
DROP POLICY IF EXISTS feature_flags_admin_delete ON public.feature_flags;
CREATE POLICY feature_flags_admin_insert ON public.feature_flags FOR INSERT TO authenticated
  WITH CHECK (public.is_current_user_super_admin());
CREATE POLICY feature_flags_admin_update ON public.feature_flags FOR UPDATE TO authenticated
  USING (public.is_current_user_super_admin())
  WITH CHECK (public.is_current_user_super_admin());
CREATE POLICY feature_flags_admin_delete ON public.feature_flags FOR DELETE TO authenticated
  USING (public.is_current_user_super_admin());

DROP POLICY IF EXISTS security_settings_admin_all ON public.security_settings;
CREATE POLICY security_settings_admin_all ON public.security_settings
  FOR ALL TO authenticated
  USING (
    public.is_current_user_super_admin()
    OR (
      tenant_id = public.get_current_tenant_id()
      AND public.user_has_permission(
        (select auth.uid()),
        'settings.write'::text,
        public.get_current_tenant_id()
      )
    )
  )
  WITH CHECK (
    public.is_current_user_super_admin()
    OR (
      tenant_id = public.assert_tenant()
      AND public.user_has_permission(
        (select auth.uid()),
        'settings.write'::text,
        public.get_current_tenant_id()
      )
    )
  );

DROP POLICY IF EXISTS rate_limit_rules_admin ON public.rate_limit_rules;
CREATE POLICY rate_limit_rules_admin ON public.rate_limit_rules
  FOR ALL TO authenticated
  USING (public.is_current_user_super_admin())
  WITH CHECK (public.is_current_user_super_admin());

DROP POLICY IF EXISTS admin_only_all ON public.cache_invalidation_queue;
CREATE POLICY admin_only_all ON public.cache_invalidation_queue
  FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);

-- -- D. FORCE ROW LEVEL SECURITY (patch 14) ------------------------------------
DO $$
DECLARE
  _tables text[] := ARRAY[
    'sections', 'lessons', 'lesson_contents',
    'users', 'sessions', 'devices',
    'roles', 'permissions', 'role_permissions',
    'settings_kv',
    'courses', 'enrollments', 'user_roles', 'user_progress',
    'notifications', 'user_notifications',
    'constants', 'user_validity_cache'
  ];
  _t text;
BEGIN
  FOREACH _t IN ARRAY _tables LOOP
    IF EXISTS (
      SELECT 1 FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = _t AND c.relkind = 'r'
    ) THEN
      EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', _t);
    END IF;
  END LOOP;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- video_cache & download_logs RLS Policies
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.video_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.download_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS video_cache_select ON public.video_cache;
CREATE POLICY video_cache_select ON public.video_cache
  FOR SELECT TO authenticated
  USING (expires_at > now());

DROP POLICY IF EXISTS download_logs_select_own ON public.download_logs;
CREATE POLICY download_logs_select_own ON public.download_logs
  FOR SELECT TO authenticated
  USING (user_id = public.get_auth_user_id() OR public.is_admin_with_session_validation());

DROP POLICY IF EXISTS download_logs_insert_own ON public.download_logs;
CREATE POLICY download_logs_insert_own ON public.download_logs
  FOR INSERT TO authenticated
  WITH CHECK (user_id = public.get_auth_user_id());

-- =============================================================================
-- AUTH SESSION BASELINE (CANONICAL)
-- Existing resource-specific RLS policies remain authoritative for ownership,
-- tenancy, and role rules. This restrictive policy adds one invariant:
-- authenticated requests must hold a currently valid session.
-- =============================================================================
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

-- SECTION-09: Direct access to partition children must never bypass the
-- parent table's tenant RLS. PostgreSQL applies parent policies to inherited
-- queries, but direct queries against a child table ignore parent policies.
-- Existing and future child partitions are therefore explicitly RLS-protected.
DO $$
DECLARE
  v_partition record;
BEGIN
  FOR v_partition IN
    SELECT child_ns.nspname AS schema_name,
           child.relname    AS partition_name
    FROM pg_inherits i
    JOIN pg_class parent      ON parent.oid = i.inhparent
    JOIN pg_namespace parent_ns ON parent_ns.oid = parent.relnamespace
    JOIN pg_class child       ON child.oid = i.inhrelid
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
  LOOP
    EXECUTE format(
      'ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY',
      v_partition.schema_name,
      v_partition.partition_name
    );
    -- No direct authenticated/anonymous policy is created intentionally:
    -- RLS default-deny protects direct child access. Parent policies remain
    -- authoritative for normal queries through the partitioned parent.
    EXECUTE format(
      'REVOKE ALL ON TABLE %I.%I FROM PUBLIC, anon, authenticated',
      v_partition.schema_name,
      v_partition.partition_name
    );
  END LOOP;
END $$;

-- SECTION-09 CRITICAL FIX: sessions_admin_all / devices_admin_all cross-tenant
-- privilege escalation.
--
-- Root cause: is_admin_with_session_validation() (aliased by
-- is_current_user_admin_lite()) returns true for ANY user whose
-- primary_role IN ('admin','super_admin') with NO tenant_id comparison at
-- all -- it only asks "is this caller an admin of any kind", never "of
-- which tenant". The two FOR ALL policies below used it as an *unscoped*
-- first OR-branch:
--
--   USING ( is_admin_with_session_validation()
--           OR (tenant_id = get_current_tenant_id() AND is_current_user_admin_lite()) )
--
-- Since is_current_user_admin_lite() IS is_admin_with_session_validation(),
-- the first branch already covers everything the second (correctly
-- tenant-scoped) branch would match, and it does so for every tenant, not
-- just the caller's own. Concretely: a plain tenant-scoped 'admin' user in
-- Tenant A could SELECT/INSERT/UPDATE/DELETE session tokens and
-- device-binding rows belonging to every OTHER tenant, purely because
-- their primary_role happened to be 'admin' anywhere in the system.
--
-- Fix: replace the unscoped branch with is_current_user_super_admin_lite(),
-- which is already strictly primary_role = 'super_admin' with no tenant
-- filter -- the only role this system's data model treats as legitimately
-- cross-tenant (see public.is_current_user_super_admin()). Tenant-scoped
-- 'admin' access is preserved unchanged via the second branch, which was
-- already correctly gated by tenant_id = get_current_tenant_id().
DROP POLICY IF EXISTS sessions_admin_all ON public.sessions;

CREATE POLICY sessions_admin_all ON public.sessions
  FOR ALL TO authenticated
  USING (
    public.is_current_user_super_admin_lite()
    OR (tenant_id = public.get_current_tenant_id() AND public.is_current_user_admin_lite())
  )
  WITH CHECK (
    public.is_current_user_super_admin_lite()
    OR (tenant_id = public.get_current_tenant_id() AND public.is_current_user_admin_lite())
  );

DROP POLICY IF EXISTS devices_admin_all ON public.devices;

CREATE POLICY devices_admin_all ON public.devices
  FOR ALL TO authenticated
  USING (
    public.is_current_user_super_admin_lite()
    OR (tenant_id = public.get_current_tenant_id() AND public.is_current_user_admin_lite())
  )
  WITH CHECK (
    public.is_current_user_super_admin_lite()
    OR (tenant_id = public.get_current_tenant_id() AND public.is_current_user_admin_lite())
  );
