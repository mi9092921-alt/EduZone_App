import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../network/supabase_client.dart';
import '../domain/event_metadata.dart';

/// Remote data source for batch-inserting log entries into Supabase.
///
/// Targets the `activity_log_queue` table, which is flushed
/// to the permanent `activity_logs` table by `pg_cron` on the server.
class LogRemoteDataSource {
  final SupabaseClient _client;

  LogRemoteDataSource([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  /// Batch-insert a list of [LogEntry] into `activity_log_queue`.
  ///
  /// Returns `true` on success, `false` on failure.
  /// Catches all exceptions to prevent sync errors from crashing the app.
  Future<bool> syncBatch(List<LogEntry> entries) async {
    if (entries.isEmpty) return true;

    try {
      final rows = entries.map((e) => e.toSupabaseMap()).toList();
      await _client.from('activity_log_queue').insert(rows);
      return true;
    } on PostgrestException catch (e) {
      debugPrint('[LogRemoteDS] Supabase insert failed: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[LogRemoteDS] Unexpected error: ${e.runtimeType}');
      return false;
    }
  }
}
