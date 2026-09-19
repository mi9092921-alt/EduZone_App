import 'package:supabase_flutter/supabase_flutter.dart';

import '../../network/supabase_client.dart';

/// Remote datasource for security-incident telemetry.
///
/// Owns the `security_incidents` table write so
/// `core/security/security_service.dart` stays a pure guard/orchestration
/// layer — core infrastructure that needs Supabase access owns its own
/// `data/` layer (same pattern as `core/logging/data`).
///
/// Writes go through the `report_security_incident` SECURITY DEFINER RPC —
/// the ONLY client write path into `security_incidents` (direct INSERT was
/// revoked server-side, dashboard repo 10_permissions.sql). The RPC accepts
/// pre-auth callers (`user_id` stays NULL — precisely preserving the
/// pre-auth nature of the event, per the 2026-09-19 product/security
/// decision), pins `user_id` to `auth.uid()` for authenticated callers,
/// validates payload shape, and absorbs volume abuse server-side. No
/// session gate here by design: the anon path is the point.
class SecurityIncidentRemoteDs {
  final SupabaseClient? _clientOverride;

  /// Optional client override, mirroring every other datasource in the app
  /// (`client ?? SupabaseService.client`): production call sites use the
  /// singleton; tests inject a mock so the datasource is unit-testable
  /// without a live Supabase.initialize.
  const SecurityIncidentRemoteDs([this._clientOverride]);

  SupabaseClient get _client => _clientOverride ?? SupabaseService.client;

  /// Best-effort submission of a security-incident telemetry record. Letting
  /// the raw [PostgrestException] escape is intentional: the caller wraps
  /// this in its own telemetry error handling (offline buffering, local
  /// fallback) and a failed incident write must never crash the guard that
  /// raised it.
  Future<void> reportIncident({
    required String threat,
    required String platform,
    String? platformVersion,
    bool isReleaseBuild = false,
    String? deviceFingerprint,
    String? appVersion,
    String? appBuildNumber,
    Map<String, dynamic>? details,
  }) async {
    await _client.rpc(
      'report_security_incident',
      params: {
        'p_threat': threat,
        'p_platform': platform,
        'p_platform_version': platformVersion,
        'p_is_release_build': isReleaseBuild,
        'p_device_fingerprint': deviceFingerprint,
        'p_app_version': appVersion,
        'p_app_build_number': appBuildNumber,
        // detected_at is stamped server-side (pg_catalog.now()): a client
        // clock is untrusted for telemetry ordering.
        'p_details': details,
      },
    );
  }
}
