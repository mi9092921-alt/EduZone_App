import '../../network/network_config.dart';
import '../../network/supabase_client.dart';

/// Remote datasource for the guarded push-token RPCs.
///
/// Owns every Supabase call for push-token lifecycle so the application
/// service (`core/services/push_token_registration_service.dart`) stays a
/// pure orchestration layer — core infrastructure that needs Supabase
/// access owns its own `data/` layer (same pattern as `core/logging/data`).
class PushTokenRemoteDs {
  const PushTokenRemoteDs();

  /// Whether a Supabase session exists (token registration only makes
  /// sense for an authenticated user).
  bool get hasAuthenticatedSession =>
      SupabaseService.client.auth.currentUser != null;

  /// Registers (or refreshes) the FCM token for the current device via the
  /// guarded `register_push_token` RPC.
  Future<void> registerPushToken({
    required String token,
    required String deviceId,
    required String platform,
    required Map<String, dynamic> deviceInfo,
    required String appVersion,
  }) async {
    await SupabaseService.client
        .rpc(
          'register_push_token',
          params: {
            'p_token': token,
            'p_device_id': deviceId,
            'p_platform': platform,
            'p_device_info': deviceInfo,
            'p_app_version': appVersion,
          },
        )
        .timeout(NetworkConfig.telemetryTimeout);
  }

  /// Deactivates the FCM token for the current device via the guarded
  /// `deactivate_push_token` RPC.
  Future<void> deactivatePushToken({
    required String? token,
    required String deviceId,
  }) async {
    await SupabaseService.client
        .rpc(
          'deactivate_push_token',
          params: {'p_token': token, 'p_device_id': deviceId},
        )
        .timeout(NetworkConfig.telemetryTimeout);
  }
}
