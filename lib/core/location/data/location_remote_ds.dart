import '../../network/supabase_client.dart';

/// Remote datasource for app-open location telemetry.
///
/// Owns the `log_app_open_location` RPC call so
/// `core/services/location_service.dart` stays a pure orchestration layer
/// (permissions, throttling, quality gates) — core infrastructure that
/// needs Supabase access owns its own `data/` layer (same pattern as
/// `core/logging/data`).
class LocationRemoteDs {
  const LocationRemoteDs();

  /// Logs one app-open location fix server-side.
  ///
  /// NOTE: no client timestamp is sent — the server uses NOW() so the fix
  /// can't be manipulated by clock drift or timezone changes on the device.
  ///
  /// Returns the RPC's string verdict (`'logged'`, `'throttled'`, ...) or
  /// null when the RPC produced no value.
  Future<String?> logAppOpenLocation({
    required double latitude,
    required double longitude,
    required double accuracy,
    required String source,
    required Map<String, dynamic> deviceInfo,
    String? sessionId,
  }) async {
    final result = await SupabaseService.client.rpc(
      'log_app_open_location',
      params: {
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_accuracy': accuracy,
        'p_source': source,
        'p_device_info': deviceInfo,
        // p_min_interval_min defaults to 3 on the server
        ...?sessionId != null ? {'p_session_id': sessionId} : null,
      },
    );
    return result?.toString();
  }
}
