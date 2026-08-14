-- ============================================================================
-- Comprehensive Seed Data Migration Helper
-- Ensures proper ordering: System Tenant → Roles → Users → Permissions
-- ============================================================================
-- Apply this AFTER the canonical schema is deployed
-- Purpose: Guarantee auth hydration works and seed data is consistent

BEGIN;
 
-- ============================================================================
-- PHASE 1: System Tenant (REQUIRED - must exist first)
-- ============================================================================
DO $$
BEGIN
  INSERT INTO public.tenants (
    id, slug, name, plan, status, region_id, data_residency, 
    max_users, max_courses, created_at, updated_at
  )
  VALUES (
    '00000000-0000-0000-0000-000000000001',
    'system',
    'System Tenant',
    'enterprise',
    'active',
    'me-south-1',
    'me-south-1',
    99999,
    99999,
    now(),
    now()
  )
  ON CONFLICT (id) DO NOTHING;
  
  RAISE NOTICE 'System Tenant created/verified: 00000000-0000-0000-0000-000000000001';
END $$;

-- ============================================================================
-- PHASE 2: System Roles (DEPENDS ON: System Tenant)
-- ============================================================================
DO $$
DECLARE
  v_system_tenant_id uuid := '00000000-0000-0000-0000-000000000001';
BEGIN
  INSERT INTO public.roles (
    tenant_id, name, label, is_system, priority, created_at, updated_at
  )
  VALUES
    (v_system_tenant_id, 'super_admin', 'Super Admin', true, 100, now(), now()),
    (v_system_tenant_id, 'admin', 'Admin', true, 80, now(), now()),
    (v_system_tenant_id, 'teacher', 'Teacher', true, 50, now(), now()),
    (v_system_tenant_id, 'student', 'Student', true, 10, now(), now())
  ON CONFLICT (tenant_id, name) DO NOTHING;
  
  RAISE NOTICE 'System roles created/verified (tenant: %)', v_system_tenant_id;
END $$;

-- ============================================================================
-- PHASE 3: System Permissions (DEPENDS ON: System Roles exist)
-- ============================================================================
-- RAISE NOTICE 'System permissions created/verified';

INSERT INTO public.permissions (name, resource, action, scope, created_at)
VALUES
  ('users.read', 'users', 'read', 'tenant', now()),
  ('users.write', 'users', 'write', 'tenant', now()),
  ('users.lock', 'users', 'lock', 'tenant', now()),
  ('courses.read', 'courses', 'read', 'tenant', now()),
  ('courses.write', 'courses', 'write', 'tenant', now()),
  ('courses.delete', 'courses', 'delete', 'tenant', now()),
  ('courses.manage', 'courses', 'manage', 'tenant', now()),
  ('reports.read', 'reports', 'read', 'tenant', now()),
  ('settings.read', 'settings', 'read', 'global', now()),
  ('settings.write', 'settings', 'write', 'global', now()),
  ('warnings.write', 'warnings', 'write', 'tenant', now()),
  ('devices.manage', 'devices', 'manage', 'tenant', now()),
  ('sessions.manage', 'sessions', 'manage', 'tenant', now()),
  ('audit.read', 'audit', 'read', 'global', now()),
  ('feature_flags.manage', 'features', 'manage', 'global', now()),
  ('tenants.manage', 'tenants', 'manage', 'global', now()),
  ('notifications.send', 'notifications', 'send', 'tenant', now()),
  ('notifications.delete', 'notifications', 'delete', 'tenant', now())
ON CONFLICT (name) DO NOTHING;

-- RAISE NOTICE 'System permissions created/verified';

-- ============================================================================
-- PHASE 4: Role-Permission Mapping (DEPENDS ON: Roles + Permissions)
-- ============================================================================
DO $$
BEGIN
  -- Super Admin gets ALL permissions
  INSERT INTO public.role_permissions (role_id, permission_id)
  SELECT r.id, p.id
  FROM public.roles r
  CROSS JOIN public.permissions p
  WHERE r.tenant_id = '00000000-0000-0000-0000-000000000001'
    AND r.name = 'super_admin'
  ON CONFLICT DO NOTHING;
  
  RAISE NOTICE 'Super admin permissions assigned';
  
  -- Admin gets all except tenant management (global)
  INSERT INTO public.role_permissions (role_id, permission_id)
  SELECT r.id, p.id
  FROM public.roles r
  CROSS JOIN public.permissions p
  WHERE r.tenant_id = '00000000-0000-0000-0000-000000000001'
    AND r.name = 'admin'
    AND p.name <> 'tenants.manage'
  ON CONFLICT DO NOTHING;
  
  RAISE NOTICE 'Admin permissions assigned';
  
  -- Teacher gets course + warning + reports + notifications
  INSERT INTO public.role_permissions (role_id, permission_id)
  SELECT r.id, p.id
  FROM public.roles r
  CROSS JOIN public.permissions p
  WHERE r.tenant_id = '00000000-0000-0000-0000-000000000001'
    AND r.name = 'teacher'
    AND p.name IN (
      'courses.read', 'courses.write', 'courses.manage', 
      'users.read', 'warnings.write', 'reports.read',
      'notifications.send', 'notifications.delete'
    )
  ON CONFLICT DO NOTHING;
  
  RAISE NOTICE 'Teacher permissions assigned';
  
  -- Student gets read permissions
  INSERT INTO public.role_permissions (role_id, permission_id)
  SELECT r.id, p.id
  FROM public.roles r
  CROSS JOIN public.permissions p
  WHERE r.tenant_id = '00000000-0000-0000-0000-000000000001'
    AND r.name = 'student'
    AND p.name IN ('courses.read', 'reports.read')
  ON CONFLICT DO NOTHING;
  
  RAISE NOTICE 'Student permissions assigned';
END $$;

-- ============================================================================
-- PHASE 5: Verify System Setup
-- ============================================================================
DO $$
DECLARE
  v_tenant_count int;
  v_role_count int;
  v_permission_count int;
BEGIN
  SELECT COUNT(*) INTO v_tenant_count 
    FROM public.tenants 
    WHERE id = '00000000-0000-0000-0000-000000000001';
  
  SELECT COUNT(*) INTO v_role_count 
    FROM public.roles 
    WHERE tenant_id = '00000000-0000-0000-0000-000000000001';
  
  SELECT COUNT(*) INTO v_permission_count 
    FROM public.permissions;
  
  RAISE NOTICE '========== SEED DATA STATUS ==========';
  RAISE NOTICE 'System Tenant(s): %', v_tenant_count;
  RAISE NOTICE 'System Roles: %', v_role_count;
  RAISE NOTICE 'Total Permissions: %', v_permission_count;
  RAISE NOTICE '======================================';
  
  IF v_tenant_count = 0 OR v_role_count < 4 OR v_permission_count = 0 THEN
    RAISE EXCEPTION 'SEED DATA VERIFICATION FAILED: Missing critical system data';
  END IF;
END $$;

-- ============================================================================
-- PHASE 6: System-level Seed Data (from Eduzone_schema_v13.sql)
-- ============================================================================

-- Setting definitions
INSERT INTO public.setting_definitions (key, expected_type, is_nullable) VALUES
  ('maintenance_mode', 'boolean', false),
  ('site_name', 'string', false)
ON CONFLICT DO NOTHING;

-- Constants
INSERT INTO public.constants (id, category, description, valid_values) VALUES
  ('REGION_ME_SOUTH_1', 'region', 'Middle East (Bahrain)', ARRAY['me-south-1']),
  ('REGION_EU_WEST_1', 'region', 'Europe (Ireland)', ARRAY['eu-west-1']),
  ('REGION_US_EAST_1', 'region', 'US East (Virginia)', ARRAY['us-east-1']),
  ('JOB_STATUS_PENDING', 'job_status', 'Job pending execution', ARRAY['pending']),
  ('JOB_STATUS_IN_PROGRESS', 'job_status', 'Job in progress', ARRAY['in_progress']),
  ('JOB_STATUS_DONE', 'job_status', 'Job completed', ARRAY['done']),
  ('JOB_STATUS_DEAD', 'job_status', 'Job failed permanently', ARRAY['dead']),
  ('FEATURE_REQUIRE_EMAIL_VERIFICATION', 'feature_flag', 'Require email verification', ARRAY['require_email_verification']),
  ('FEATURE_REQUIRE_2FA', 'feature_flag', 'Require 2FA for admin accounts', ARRAY['require_2fa']),
  ('FEATURE_MAX_LOGIN_ATTEMPTS', 'feature_flag', 'Max login attempts before lockout', ARRAY['max_login_attempts']),
  ('COURSE_STATUS_DRAFT', 'course_status', 'Course is draft', ARRAY['draft']),
  ('COURSE_STATUS_PUBLISHED', 'course_status', 'Course is published', ARRAY['published']),
  ('COURSE_STATUS_ARCHIVED', 'course_status', 'Course is archived', ARRAY['archived']),
  ('ENROLLMENT_STATUS_ACTIVE', 'enrollment_status', 'Active enrollment', ARRAY['active']),
  ('ENROLLMENT_STATUS_REVOKED', 'enrollment_status', 'Enrollment revoked', ARRAY['revoked']),
  ('ENROLLMENT_STATUS_EXPIRED', 'enrollment_status', 'Enrollment expired', ARRAY['expired']),
  ('ENROLLMENT_STATUS_COMPLETED', 'enrollment_status', 'Enrollment completed', ARRAY['completed']),
  ('ACCOUNT_STATUS_ACTIVE', 'account_status', 'Account active', ARRAY['active']),
  ('ACCOUNT_STATUS_INACTIVE', 'account_status', 'Account inactive', ARRAY['inactive']),
  ('ACCOUNT_STATUS_SUSPENDED', 'account_status', 'Account suspended', ARRAY['suspended']),
  ('ACCOUNT_STATUS_LOCKED', 'account_status', 'Account locked', ARRAY['locked']),
  ('ACCOUNT_STATUS_BANNED', 'account_status', 'Account banned', ARRAY['banned'])
ON CONFLICT (id) DO NOTHING;

-- Regions
INSERT INTO public.regions (id, label, is_active, is_primary) VALUES
  ('me-south-1', 'Middle East (Bahrain)', true, true),
  ('eu-west-1', 'Europe (Ireland)', true, false),
  ('us-east-1', 'US East (Virginia)', true, false)
ON CONFLICT (id) DO NOTHING;

-- System Settings
INSERT INTO public.settings_kv (key, value, category, description, is_public) VALUES
  ('app_locked', 'false'::jsonb, 'security', 'Global app lock', true),
  ('app_lock_message', '"Application is temporarily locked."'::jsonb, 'security', 'Global lock message', true),
  ('maintenance_mode', 'false'::jsonb, 'maintenance', 'Maintenance mode', true),
  ('maintenance_message', '"Application is under maintenance."'::jsonb, 'maintenance', 'Maintenance message', true),
  ('settings_cache_ttl_seconds', '300'::jsonb, 'limits', 'Settings cache TTL', false),
  ('max_devices_per_user', '1'::jsonb, 'limits', 'Maximum active devices per user', false),
  ('max_concurrent_streams', '2'::jsonb, 'limits', 'Maximum concurrent streams per student', false),
  ('content_signed_url_ttl_sec', '3600'::jsonb, 'limits', 'Content signed URL TTL', false),
  ('preview_lessons_enabled', 'true'::jsonb, 'general', 'Allow preview lessons', true)
ON CONFLICT (key) DO NOTHING;

-- Additional seeds from Eduzone_schema_v13.sql
INSERT INTO public.rate_limit_rules (action, window_seconds, max_hits, block_seconds, is_active) VALUES
  ('login',          300,   5,   900,  true),
  ('api_call',       60,    120, 60,   true),
  ('video_view',     3600,  50,  0,    true),
  ('device_bind',    86400, 3,   3600, true),
  ('password_reset', 3600,  3,   7200, true),
  ('warning_issue',  3600,  20,  0,    true),
  ('content_access', 3600,  200, 0,    true)
ON CONFLICT (action) DO NOTHING;

INSERT INTO public.feature_flags (key, description, is_enabled, rollout_pct) VALUES
  ('new_ui',             'New UI experience',           false, 0),
  ('chat_enabled',       'In-app chat system',          false, 0),
  ('beta_mode',          'Beta feature set',            false, 0),
  ('live_sessions',      'Live class sessions',         false, 0),
  ('ai_tutor',           'AI tutoring assistant',       false, 0),
  ('dark_mode',          'Dark mode toggle',            true,  100),
  ('push_notifications', 'Push notification system',   true,  100),
  ('screen_watermark',   'Dynamic watermark overlay',   false, 0),
  ('geo_restriction',    'Geographic access control',   false, 0),
  ('hls_streaming',      'HLS encrypted streaming',     false, 0)
ON CONFLICT (key) DO NOTHING;

INSERT INTO public.settings_kv (key, value, category, description, is_public) VALUES
  ('maintenance_excluded_roles', '["super_admin","admin"]'::jsonb, 'maintenance', 'Roles excluded from maintenance mode', false),
  ('maintenance_excluded_users', '[]'::jsonb, 'maintenance', 'Users excluded from maintenance mode', false),
  ('maintenance_ends_at', 'null'::jsonb, 'maintenance', 'Scheduled maintenance end time', true),
  ('max_warnings_before_action', '3'::jsonb, 'limits', 'Warnings before automatic action', false),
  ('session_timeout_minutes', '1440'::jsonb, 'limits', 'Session timeout in minutes', false),
  ('force_single_session', 'true'::jsonb, 'limits', 'Prevent multiple concurrent logins', false),
  ('log_flush_batch_size', '100'::jsonb, 'limits', 'Activity log flush batch size', false),
  ('risk_score_block_threshold', '70'::jsonb, 'security', 'Risk score threshold for blocking', false),
  ('geo_restriction_enabled', 'false'::jsonb, 'security', 'Enable geographic restrictions', false),
  ('allowed_countries', '["EG"]'::jsonb, 'security', 'Allowed country codes', false),
  ('latest_version', '"1.0.0"'::jsonb, 'general', 'Latest app version', true),
  ('min_app_version', '"1.0.0"'::jsonb, 'general', 'Minimum required app version', true),
  ('force_update', 'false'::jsonb, 'general', 'Force app update', true),
  ('update_message', '""'::jsonb, 'general', 'App update message', true),
  ('support_link', '""'::jsonb, 'general', 'Support URL', true),
  ('store_link_android', '""'::jsonb, 'general', 'Google Play Store URL', true),
  ('store_link_ios', '""'::jsonb, 'general', 'Apple App Store URL', true),
  ('follow_link', '""'::jsonb, 'general', 'Social follow URL', true),
  ('retention_deleted_user_days', '90'::jsonb, 'compliance', 'Days to keep soft-deleted user records', false),
  ('retention_activity_log_days', '365'::jsonb, 'compliance', 'Days to keep activity logs', false),
  ('retention_location_log_days', '30'::jsonb, 'compliance', 'Days to keep location logs (GDPR)', false)
ON CONFLICT (key) DO NOTHING;

-- Audit Chain State
INSERT INTO public.audit_chain_state (id, last_seq, last_hash)
VALUES (1, 0, repeat('0', 64))
ON CONFLICT (id) DO NOTHING;

COMMIT;
