import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../network/network_config.dart';
import '../../network/supabase_client.dart';
import '../domain/event_metadata.dart';

/// Remote data source for submitting log entries to Supabase.
///
/// `public.activity_log_queue` has `REVOKE ALL ... FROM anon, authenticated`
/// plus a `FOR ALL TO public USING (false)` deny-all RLS policy
/// (supabase/schema/09_rls.sql, supabase/schema/10_permissions.sql) — direct
/// `.from('activity_log_queue').insert(...)` is intentionally blocked for
/// every client role at the database layer ("CRIT-05: Deny all PostgREST
/// access to internal tables"). The only client write path is the
/// `public.log_activity_async` RPC (SECURITY DEFINER, validates
/// `p_user_id = auth.uid()` server-side before writing), which forwards
/// into `internal.log_activity_internal`. Entries are submitted one RPC
/// call per entry since the RPC is scalar, not a batch insert.
class LogRemoteDataSource {
  final SupabaseClient _client;

  LogRemoteDataSource([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  /// Submit a list of [LogEntry] via `public.log_activity_async`.
  ///
  /// Returns `true` only if every entry in the batch was accepted.
  /// On any failure the whole batch is reported as failed so
  /// [SyncEngine] requeues it for retry — matching the queue's existing
  /// at-least-once, no-local-persistence delivery model (duplicate rows
  /// on a retried partial failure are an accepted trade-off for
  /// non-critical telemetry, same as before this fix).
  Future<bool> syncBatch(List<LogEntry> entries) async {
    if (entries.isEmpty) return true;

    try {
      for (final entry in entries) {
        // `p_device_id` is intentionally omitted (left at the RPC's own
        // NULL default): `AppEvent.deviceId`/`LogEntry.deviceId` is
        // populated in practice as a free-form device *fingerprint*
        // string (see offline_policy_engine.dart's `_deviceFingerprint()`
        // -- the only current caller that sets it at all), not the
        // `public.devices.id` uuid primary key that
        // `log_activity_async(..., p_device_id uuid, ...)` expects.
        // Passing a non-UUID string through would throw an
        // "invalid input syntax for type uuid" error on every such
        // call and fail the whole batch -- worse than simply not
        // attaching a device id to these log rows.
        await _client.rpc(
          'log_activity_async',
          params: {
            'p_user_id': entry.userId,
            'p_type': entry.eventType,
            'p_details': entry.details,
            'p_risk_level': entry.riskLevel,
          },
        ).timeout(NetworkConfig.telemetryTimeout);
      }
      return true;
    } on PostgrestException catch (e) {
      debugPrint(
        '[LogRemoteDS] Supabase RPC failed: ${e.code ?? 'unknown'}',
      );
      return false;
    } catch (e) {
      debugPrint('[LogRemoteDS] Unexpected error: ${e.runtimeType}');
      return false;
    }
  }
}
