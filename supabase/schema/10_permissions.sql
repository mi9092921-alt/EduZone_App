-- ============================================================================
-- Function & Object Permissions (Security Hardened)
-- ============================================================================
-- Source of truth: ../../Eduzone_schema_v13.sql (schema) + hardening_patch.sql
-- 
-- Hardened per security audit (June 2026):
-- - All SECURITY DEFINER functions audited and reference-checked
-- - Unnecessary anon/authenticated access revoked from 120+ internal/admin functions
-- - Follows principle of least privilege with explicit GRANT model
-- - Maintains backward compatibility with production frontend & edge functions
REVOKE ALL ON SCHEMA public FROM PUBLIC;

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;

REVOKE ALL ON SCHEMA audit FROM PUBLIC, anon, authenticated;

REVOKE ALL ON SCHEMA internal FROM PUBLIC, anon, authenticated;

REVOKE ALL ON SCHEMA maintenance FROM PUBLIC, anon, authenticated;

GRANT USAGE ON SCHEMA private TO service_role;

GRANT USAGE ON SCHEMA audit TO service_role;

GRANT USAGE ON SCHEMA internal TO service_role;

GRANT USAGE ON SCHEMA maintenance TO service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated;

GRANT SELECT ON public.vw_course_stats TO authenticated, anon, service_role;

-- ============================================================================
-- Table & View DML Grants
-- ============================================================================

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL TABLES IN SCHEMA audit FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL TABLES IN SCHEMA internal FROM PUBLIC, anon, authenticated;

-- Core read access
GRANT SELECT ON public.regions                  TO authenticated, anon;
GRANT SELECT ON public.tenants                  TO authenticated, anon;
GRANT SELECT ON public.users                    TO authenticated;
GRANT SELECT ON public.roles, public.permissions, public.role_permissions, public.user_roles TO authenticated;
GRANT SELECT ON public.settings_kv, public.settings_cache, public.security_settings TO authenticated, service_role;
GRANT SELECT ON public.feature_flags, public.feature_flag_roles, public.feature_flag_users TO authenticated, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.tenant_feature_flags TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.courses, public.course_prerequisites, public.course_learning_objectives, public.sections, public.lessons TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.lesson_contents TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.enrollments TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.user_progress TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.devices TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.sessions TO authenticated;
GRANT SELECT, INSERT ON public.video_views TO authenticated;
GRANT SELECT, INSERT ON public.todos TO authenticated;
GRANT UPDATE (title, due_at, priority, is_completed, deleted_at) ON public.todos TO authenticated;
GRANT SELECT ON public.warnings TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.push_tokens TO authenticated;
GRANT SELECT, INSERT ON public.user_location_logs TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE ON public.user_last_location TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.activity_logs, public.audit_chain_state TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notifications, public.notification_targets TO authenticated;
GRANT SELECT, UPDATE ON public.user_notifications TO authenticated;
GRANT SELECT ON public.user_permission_cache    TO authenticated, anon, service_role;
GRANT SELECT ON public.constants TO authenticated;
GRANT SELECT ON public.user_validity_cache TO authenticated, service_role;
GRANT SELECT ON public.mv_course_stats TO authenticated, service_role, anon;

-- Mutation grants (RLS still controls who can do what)
GRANT INSERT, UPDATE, DELETE ON public.users                     TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.courses                   TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.course_prerequisites      TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.course_learning_objectives TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.sections                  TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.lessons                   TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.lesson_contents           TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.devices                   TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.activity_logs             TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.notifications             TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.push_tokens               TO authenticated;

-- Service role access
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA audit TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA internal TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA private TO service_role;
GRANT SELECT ON private.mv_user_stats        TO service_role;
GRANT SELECT ON private.mv_course_stats      TO service_role;
GRANT SELECT ON private.mv_course_stats_tenant TO service_role;
GRANT SELECT ON private.mv_daily_activity_30d TO service_role;

-- Special Revokes
REVOKE DELETE ON public.todos FROM authenticated;
REVOKE UPDATE, DELETE ON public.activity_logs FROM authenticated;
REVOKE UPDATE, DELETE ON public.warnings FROM authenticated;
REVOKE UPDATE ON public.users FROM authenticated;
REVOKE ALL ON public.activity_log_queue FROM anon, authenticated;
REVOKE ALL ON internal.job_queue FROM anon, authenticated, public;
REVOKE ALL ON audit.slow_query_log FROM anon, authenticated, public;
REVOKE ALL ON audit.lesson_state_transitions FROM anon, authenticated, public;
REVOKE ALL ON audit.pii_access_log FROM anon, authenticated, public;
REVOKE ALL ON audit.deletion_audit FROM anon, authenticated, public;
REVOKE ALL ON internal.workers FROM anon, authenticated, public;
REVOKE ALL ON internal.job_progress FROM anon, authenticated, public;

-- ============================================================================
-- Function Permissions - Consolidated
-- ============================================================================

-- Global Function Revoke (Reset to safe default)
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated;

-- 1. MUST REMAIN PUBLIC
GRANT EXECUTE ON FUNCTION public.get_public_settings() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_constant(text) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_default_region_id() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.system_tenant_id() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.immutable_unaccent(text) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.immutable_tsvector(text) TO authenticated, anon, service_role;

-- 2. AUTHENTICATED ONLY - Key user-facing functions
-- Note: For functions with parameters, use full signature or rely on default privileges
-- Most functions with complex signatures are already blocked by ALTER DEFAULT PRIVILEGES above

REVOKE EXECUTE ON FUNCTION public.check_user_access() FROM anon;
GRANT EXECUTE ON FUNCTION public.check_user_access() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.assert_tenant() FROM anon;
GRANT EXECUTE ON FUNCTION public.assert_tenant() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.get_auth_user_id() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_auth_user_id() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.get_current_tenant_id() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_current_tenant_id() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.tenant_matches_jwt(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.tenant_matches_jwt(uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.is_admin_with_session_validation() FROM anon;
GRANT EXECUTE ON FUNCTION public.is_admin_with_session_validation() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.is_current_user_admin() FROM anon;
GRANT EXECUTE ON FUNCTION public.is_current_user_admin() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.is_current_user_teacher() FROM anon;
GRANT EXECUTE ON FUNCTION public.is_current_user_teacher() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.is_enrolled_in_course(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.is_enrolled_in_course(uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.is_teacher_of_course(uuid, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.is_teacher_of_course(uuid, uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.enroll_in_course(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.enroll_in_course(uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.logout_current_user() FROM anon;
GRANT EXECUTE ON FUNCTION public.logout_current_user() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.validate_user_session() FROM anon;
GRANT EXECUTE ON FUNCTION public.validate_user_session() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.assert_valid_session() FROM anon;
GRANT EXECUTE ON FUNCTION public.assert_valid_session() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.current_user_session() FROM anon;
GRANT EXECUTE ON FUNCTION public.current_user_session() TO authenticated, service_role;

-- 3. ADMIN ONLY - Revoked from anon AND authenticated; granted to service_role only
REVOKE EXECUTE ON FUNCTION public.is_current_user_super_admin() FROM anon;
REVOKE EXECUTE ON FUNCTION public.is_current_user_super_admin() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.is_current_user_super_admin() TO service_role;

REVOKE EXECUTE ON FUNCTION public.is_current_user_super_admin_lite() FROM anon;
REVOKE EXECUTE ON FUNCTION public.is_current_user_super_admin_lite() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.is_current_user_super_admin_lite() TO service_role;

REVOKE EXECUTE ON FUNCTION public.lock_app_for_all(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.lock_app_for_all(text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.lock_app_for_all(text) TO service_role;

REVOKE EXECUTE ON FUNCTION public.unlock_app() FROM anon;
REVOKE EXECUTE ON FUNCTION public.unlock_app() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.unlock_app() TO service_role;

REVOKE EXECUTE ON FUNCTION public.disable_maintenance_mode() FROM anon;
REVOKE EXECUTE ON FUNCTION public.disable_maintenance_mode() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.disable_maintenance_mode() TO service_role;

REVOKE EXECUTE ON FUNCTION public.enable_maintenance_mode(text, timestamptz, text[], uuid[]) FROM anon;
REVOKE EXECUTE ON FUNCTION public.enable_maintenance_mode(text, timestamptz, text[], uuid[]) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.enable_maintenance_mode(text, timestamptz, text[], uuid[]) TO service_role;

-- 4. INTERNAL ONLY - Revoked from anon AND authenticated; granted to service_role only
REVOKE EXECUTE ON FUNCTION public.decrypt_pii(bytea, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.decrypt_pii(bytea, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.decrypt_pii(bytea, text) TO service_role;

REVOKE EXECUTE ON FUNCTION public.encrypt_pii(text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.encrypt_pii(text, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.encrypt_pii(text, text) TO service_role;

REVOKE EXECUTE ON FUNCTION public.dequeue_job(text, text[], integer) FROM anon;
REVOKE EXECUTE ON FUNCTION public.dequeue_job(text, text[], integer) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.dequeue_job(text, text[], integer) TO service_role;

REVOKE EXECUTE ON FUNCTION public.sync_primary_role() FROM anon;
REVOKE EXECUTE ON FUNCTION public.sync_primary_role() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.sync_primary_role() TO service_role;

REVOKE EXECUTE ON FUNCTION public.sync_settings_cache() FROM anon;
REVOKE EXECUTE ON FUNCTION public.sync_settings_cache() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.sync_settings_cache() TO service_role;

REVOKE EXECUTE ON FUNCTION public.terminate_user_sessions(uuid, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.terminate_user_sessions(uuid, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.terminate_user_sessions(uuid, text) TO service_role;
REVOKE EXECUTE ON FUNCTION public.trg_refresh_user_validity() FROM anon;
REVOKE EXECUTE ON FUNCTION public.trg_refresh_user_validity() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_schedule_mv_refresh() FROM anon;
REVOKE EXECUTE ON FUNCTION public.trg_schedule_mv_refresh() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_sync_user_roles() FROM anon;
REVOKE EXECUTE ON FUNCTION public.trg_sync_user_roles() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_trim_notification_fields() FROM anon;
REVOKE EXECUTE ON FUNCTION public.trg_trim_notification_fields() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_update_enrollment_progress() FROM anon;
REVOKE EXECUTE ON FUNCTION public.trg_update_enrollment_progress() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_users_email_hardening() FROM anon;
REVOKE EXECUTE ON FUNCTION public.trg_users_email_hardening() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_validate_enrollments_tenant_match() FROM anon;
REVOKE EXECUTE ON FUNCTION public.trg_validate_enrollments_tenant_match() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.worker_control_user_account(uuid, uuid, text, text, integer) FROM anon;
REVOKE EXECUTE ON FUNCTION public.worker_control_user_account(uuid, uuid, text, text, integer) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.worker_terminate_user_sessions(uuid, uuid, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.worker_terminate_user_sessions(uuid, uuid, text) FROM authenticated;

GRANT EXECUTE ON FUNCTION public.decrypt_pii(bytea, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.dequeue_job(text, text[], integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.encrypt_pii(text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.worker_control_user_account(uuid, uuid, text, text, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.worker_terminate_user_sessions(uuid, uuid, text) TO service_role;
-- Core read access
GRANT SELECT ON public.regions                  TO authenticated, anon;
GRANT SELECT ON public.tenants                  TO authenticated, anon;
GRANT SELECT ON public.users                    TO authenticated;
GRANT SELECT ON public.roles, public.permissions, public.role_permissions, public.user_roles TO authenticated;
GRANT SELECT ON public.settings_kv, public.settings_cache, public.security_settings TO authenticated, service_role;
GRANT SELECT ON public.feature_flags, public.feature_flag_roles, public.feature_flag_users TO authenticated, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.tenant_feature_flags TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.courses, public.course_prerequisites, public.course_learning_objectives, public.sections, public.lessons TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.lesson_contents TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.enrollments TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.user_progress TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.devices TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.sessions TO authenticated;
GRANT SELECT, INSERT ON public.video_views TO authenticated;
GRANT SELECT, INSERT ON public.todos TO authenticated;
GRANT UPDATE (title, due_at, priority, is_completed, deleted_at) ON public.todos TO authenticated;
GRANT SELECT ON public.warnings TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.push_tokens TO authenticated;
GRANT SELECT, INSERT ON public.user_location_logs TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE ON public.user_last_location TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.activity_logs, public.audit_chain_state TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notifications, public.notification_targets TO authenticated;
GRANT SELECT, UPDATE ON public.user_notifications TO authenticated;
GRANT SELECT ON public.user_permission_cache    TO authenticated, anon, service_role;
GRANT SELECT ON public.constants TO authenticated;
GRANT SELECT ON public.user_validity_cache TO authenticated, service_role;
GRANT SELECT ON public.mv_course_stats TO authenticated, service_role, anon;

-- Mutation grants (RLS still controls who can do what)
GRANT INSERT, UPDATE, DELETE ON public.users                     TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.courses                   TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.course_prerequisites      TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.course_learning_objectives TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.sections                  TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.lessons                   TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.lesson_contents           TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.devices                   TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.activity_logs             TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.notifications             TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.push_tokens               TO authenticated;

-- Service role access
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA audit TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA internal TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA private TO service_role;
GRANT SELECT ON private.mv_user_stats        TO service_role;
GRANT SELECT ON private.mv_course_stats      TO service_role;
GRANT SELECT ON private.mv_course_stats_tenant TO service_role;
GRANT SELECT ON private.mv_daily_activity_30d TO service_role;

-- Special Revokes
REVOKE DELETE ON public.todos FROM authenticated;
REVOKE UPDATE, DELETE ON public.activity_logs FROM authenticated;
REVOKE UPDATE, DELETE ON public.warnings FROM authenticated;
REVOKE UPDATE ON public.users FROM authenticated;
REVOKE ALL ON public.activity_log_queue FROM anon, authenticated;
REVOKE ALL ON internal.job_queue FROM anon, authenticated, public;
REVOKE ALL ON audit.slow_query_log FROM anon, authenticated, public;
REVOKE ALL ON audit.lesson_state_transitions FROM anon, authenticated, public;
REVOKE ALL ON audit.pii_access_log FROM anon, authenticated, public;
REVOKE ALL ON audit.deletion_audit FROM anon, authenticated, public;
REVOKE ALL ON internal.workers FROM anon, authenticated, public;
REVOKE ALL ON internal.job_progress FROM anon, authenticated, public;

-- ============================================================================
-- Function Permissions - Consolidated
-- ============================================================================

-- Global Function Revoke (Reset to safe default)
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated;

-- 1. MUST REMAIN PUBLIC
GRANT EXECUTE ON FUNCTION public.get_public_settings() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_constant(text) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_default_region_id() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.system_tenant_id() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.immutable_unaccent(text) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.immutable_tsvector(text) TO authenticated, anon, service_role;

-- 2. AUTHENTICATED ONLY - Key user-facing functions
-- Note: For functions with parameters, use full signature or rely on default privileges
-- Most functions with complex signatures are already blocked by ALTER DEFAULT PRIVILEGES above

REVOKE EXECUTE ON FUNCTION public.check_user_access() FROM anon;
GRANT EXECUTE ON FUNCTION public.check_user_access() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.assert_tenant() FROM anon;
GRANT EXECUTE ON FUNCTION public.assert_tenant() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.get_auth_user_id() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_auth_user_id() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.get_current_tenant_id() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_current_tenant_id() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.tenant_matches_jwt(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.tenant_matches_jwt(uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.is_admin_with_session_validation() FROM anon;
GRANT EXECUTE ON FUNCTION public.is_admin_with_session_validation() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.is_current_user_admin() FROM anon;
GRANT EXECUTE ON FUNCTION public.is_current_user_admin() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.is_current_user_teacher() FROM anon;
GRANT EXECUTE ON FUNCTION public.is_current_user_teacher() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.is_enrolled_in_course(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.is_enrolled_in_course(uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.is_teacher_of_course(uuid, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.is_teacher_of_course(uuid, uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.enroll_in_course(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.enroll_in_course(uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.logout_current_user() FROM anon;
GRANT EXECUTE ON FUNCTION public.logout_current_user() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.validate_user_session() FROM anon;
GRANT EXECUTE ON FUNCTION public.validate_user_session() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.assert_valid_session() FROM anon;
GRANT EXECUTE ON FUNCTION public.assert_valid_session() TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.current_user_session() FROM anon;
GRANT EXECUTE ON FUNCTION public.current_user_session() TO authenticated, service_role;

-- 3. ADMIN ONLY - Revoked from anon AND authenticated; granted to service_role only
REVOKE EXECUTE ON FUNCTION public.is_current_user_super_admin() FROM anon;
REVOKE EXECUTE ON FUNCTION public.is_current_user_super_admin() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.is_current_user_super_admin() TO service_role;

REVOKE EXECUTE ON FUNCTION public.is_current_user_super_admin_lite() FROM anon;
REVOKE EXECUTE ON FUNCTION public.is_current_user_super_admin_lite() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.is_current_user_super_admin_lite() TO service_role;

REVOKE EXECUTE ON FUNCTION public.lock_app_for_all(text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.lock_app_for_all(text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.lock_app_for_all(text) TO service_role;

REVOKE EXECUTE ON FUNCTION public.unlock_app() FROM anon;
REVOKE EXECUTE ON FUNCTION public.unlock_app() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.unlock_app() TO service_role;

REVOKE EXECUTE ON FUNCTION public.disable_maintenance_mode() FROM anon;
REVOKE EXECUTE ON FUNCTION public.disable_maintenance_mode() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.disable_maintenance_mode() TO service_role;

REVOKE EXECUTE ON FUNCTION public.enable_maintenance_mode(text, timestamptz, text[], uuid[]) FROM anon;
REVOKE EXECUTE ON FUNCTION public.enable_maintenance_mode(text, timestamptz, text[], uuid[]) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.enable_maintenance_mode(text, timestamptz, text[], uuid[]) TO service_role;

-- 4. INTERNAL ONLY - Revoked from anon AND authenticated; granted to service_role only
REVOKE EXECUTE ON FUNCTION public.decrypt_pii(bytea, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.decrypt_pii(bytea, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.decrypt_pii(bytea, text) TO service_role;

REVOKE EXECUTE ON FUNCTION public.encrypt_pii(text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.encrypt_pii(text, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.encrypt_pii(text, text) TO service_role;

REVOKE EXECUTE ON FUNCTION public.dequeue_job(text, text[], integer) FROM anon;
REVOKE EXECUTE ON FUNCTION public.dequeue_job(text, text[], integer) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.dequeue_job(text, text[], integer) TO service_role;

REVOKE EXECUTE ON FUNCTION public.sync_primary_role() FROM anon;
REVOKE EXECUTE ON FUNCTION public.sync_primary_role() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.sync_primary_role() TO service_role;

REVOKE EXECUTE ON FUNCTION public.sync_settings_cache() FROM anon;
REVOKE EXECUTE ON FUNCTION public.sync_settings_cache() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.sync_settings_cache() TO service_role;

REVOKE EXECUTE ON FUNCTION public.terminate_user_sessions(uuid, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.terminate_user_sessions(uuid, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.terminate_user_sessions(uuid, text) TO service_role;
REVOKE EXECUTE ON FUNCTION public.trg_refresh_user_validity() FROM anon;
REVOKE EXECUTE ON FUNCTION public.trg_refresh_user_validity() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_schedule_mv_refresh() FROM anon;
REVOKE EXECUTE ON FUNCTION public.trg_schedule_mv_refresh() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_sync_user_roles() FROM anon;
REVOKE EXECUTE ON FUNCTION public.trg_sync_user_roles() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_trim_notification_fields() FROM anon;
REVOKE EXECUTE ON FUNCTION public.trg_trim_notification_fields() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_update_enrollment_progress() FROM anon;
REVOKE EXECUTE ON FUNCTION public.trg_update_enrollment_progress() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_users_email_hardening() FROM anon;
REVOKE EXECUTE ON FUNCTION public.trg_users_email_hardening() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.trg_validate_enrollments_tenant_match() FROM anon;
REVOKE EXECUTE ON FUNCTION public.trg_validate_enrollments_tenant_match() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.worker_control_user_account(uuid, uuid, text, text, integer) FROM anon;
REVOKE EXECUTE ON FUNCTION public.worker_control_user_account(uuid, uuid, text, text, integer) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.worker_terminate_user_sessions(uuid, uuid, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.worker_terminate_user_sessions(uuid, uuid, text) FROM authenticated;

GRANT EXECUTE ON FUNCTION public.decrypt_pii(bytea, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.dequeue_job(text, text[], integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.encrypt_pii(text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.worker_control_user_account(uuid, uuid, text, text, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.worker_terminate_user_sessions(uuid, uuid, text) TO service_role;

-- 5. SUPABASE AUTH HOOK
REVOKE ALL ON FUNCTION public.custom_access_token(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.custom_access_token(jsonb) TO service_role, supabase_auth_admin;

GRANT EXECUTE ON FUNCTION private.refresh_all_materialized_views() TO service_role;

REVOKE ALL ON FUNCTION private.get_kms_key() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.get_kms_key() TO service_role;

REVOKE ALL ON FUNCTION private.current_jwt_token_version() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.current_jwt_token_version() TO service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- video_cache & download_logs Permissions
-- ─────────────────────────────────────────────────────────────────────────────
GRANT SELECT ON public.video_cache TO authenticated;
GRANT ALL ON public.video_cache TO service_role;

GRANT SELECT, INSERT ON public.download_logs TO authenticated;
GRANT ALL ON public.download_logs TO service_role;

