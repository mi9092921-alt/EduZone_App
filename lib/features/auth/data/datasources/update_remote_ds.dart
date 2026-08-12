import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client.dart';

/// Fetches app update configuration from the `app_config` table.
///
/// Reads only the 6 keys relevant to update management.
/// Returns a normalized [Map<String, dynamic>] — raw parsing happens
/// in [UpdateService], not here.
class UpdateRemoteDataSource {
  final SupabaseClient _client;

  UpdateRemoteDataSource([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  static const _updateKeys = [
    'latest_version',
    'min_app_version',
    'force_update',
    'update_message',
    'store_link_android',
    'store_link_ios',
    // Fallback key — used if store_link_android/ios are not yet in schema
    'support_link',
  ];

  /// Returns a flat key→value map. The `value` column in app_config
  /// is JSONB so booleans/strings arrive as Dart native types after
  /// Supabase deserialization.
  Future<Map<String, dynamic>> fetchConfig() async {
    final rows = await _client
        .from('settings_kv')
        .select('key, value')
        .inFilter('key', _updateKeys);

    final map = <String, dynamic>{};
    for (final row in rows as List<dynamic>) {
      final jsonRow = row as Map<String, dynamic>;
      final key = jsonRow['key'] as String;
      final value = jsonRow['value'];
      // JSONB booleans arrive as Dart bool; strings may be quoted — unwrap
      map[key] = (value is String)
          ? value.replaceAll('"', '').trim()
          : value;
    }
    return map;
  }
}
