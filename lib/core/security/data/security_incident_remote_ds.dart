import 'package:supabase_flutter/supabase_flutter.dart';

import '../../network/supabase_client.dart';

/// Remote datasource for security-incident telemetry.
///
/// Owns the `security_incidents` table write so
/// `core/security/security_service.dart` stays a pure guard/orchestration
/// layer — core infrastructure that needs Supabase access owns its own
/// `data/` layer (same pattern as `core/logging/data`).
class SecurityIncidentRemoteDs {
  const SecurityIncidentRemoteDs();

  /// Best-effort insert of a security incident payload. Letting the raw
  /// [PostgrestException] escape is intentional: the callers wrap this in
  /// their own telemetry error handling (offline buffering, local fallback)
  /// and a failed incident write must never crash the guard that raised it.
  Future<void> insertIncident(Map<String, dynamic> payload) async {
    await SupabaseService.client.from('security_incidents').insert(payload);
  }
}
