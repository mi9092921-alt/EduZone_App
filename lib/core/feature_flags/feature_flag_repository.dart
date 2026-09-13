import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/network_guard.dart';
import '../network/supabase_client.dart';
import 'feature_flag_keys.dart';
import 'feature_flag_snapshot.dart';

/// Data access to the canonical server-side feature-flag evaluator.
///
/// The ONLY network path of the feature-flag module. Calls
/// `public.evaluate_feature_flags(p_keys text[])` (SECURITY DEFINER,
/// supabase/schema/07_functions.sql) which:
///
/// * derives the user/tenant from the authenticated JWT — the client sends
///   flag keys only and cannot influence targeting or rollout;
/// * returns an empty result set for unauthenticated/invalid sessions
///   (safe: the caller then falls back to client defaults);
/// * returns one `(key, enabled, version)` row per requested key, with
///   `version = 0` for keys it does not know.
///
/// All user-visible/security-relevant behavior stays enforced server-side;
/// this repository only relays the evaluator's verdict.
class FeatureFlagRepository {
  FeatureFlagRepository({SupabaseClient? client}) : _clientOverride = client;

  /// Test/client override; resolved lazily (see [_client]).
  final SupabaseClient? _clientOverride;

  /// Resolved at CALL time, not construction time: the module's providers
  /// must be mountable in any environment (including unit tests without an
  /// initialized Supabase) without throwing, and fail only when actually
  /// used — where callers already handle failure.
  SupabaseClient get _client => _clientOverride ?? SupabaseService.client;

  /// Id of the currently authenticated Supabase user, or null when signed
  /// out. Used by the provider to key the local cache per account so one
  /// user's snapshot can never be served to another.
  ///
  /// Never throws: when the backend layer is unavailable (Supabase not
  /// initialized — unit tests), "no session" is the safe interpretation.
  String? get currentUserId {
    try {
      return _client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  /// Evaluates every registry flag in one batch and returns the raw
  /// per-key verdicts (registered and unregistered alike — the snapshot
  /// factory decides how to interpret `version == 0`).
  ///
  /// Routed through [NetworkGuard.read] (bounded timeout + transient-only
  /// retry, same policy as every other read datasource). Throws typed
  /// [AppException]s on failure; callers keep their previous snapshot.
  ///
  /// Malformed individual rows are skipped rather than failing the batch:
  /// one bad row must not strip every other flag down to defaults.
  Future<List<FeatureFlagEvaluation>> evaluate(List<FeatureFlagKey> keys) {
    assert(
      keys.length <= _maxKeysPerRequest,
      'The canonical evaluator accepts at most $_maxKeysPerRequest keys '
      'per request; the registry grew past the RPC limit.',
    );

    if (keys.isEmpty) return Future.value(const []);

    return NetworkGuard.read(() async {
      final rows = await _client.rpc(
        'evaluate_feature_flags',
        params: {'p_keys': keys.map((key) => key.serverKey).toList()},
      );

      return _parseRows(rows);
    });
  }

  static const int _maxKeysPerRequest = 100;

  static List<FeatureFlagEvaluation> _parseRows(Object? rows) {
    if (rows is! List) return const [];

    final evaluations = <FeatureFlagEvaluation>[];
    for (final row in rows) {
      if (row is! Map) continue;

      final rawKey = row['key'];
      final rawEnabled = row['enabled'];
      final rawVersion = row['version'];
      if (rawKey is! String || rawEnabled is! bool) continue;

      final key = FeatureFlagKey.fromServerKey(rawKey);
      // Server may know flags registered for newer app versions — the
      // current build has no behavior attached to them, so skip.
      if (key == null) continue;

      evaluations.add(
        FeatureFlagEvaluation(
          key: key,
          enabled: rawEnabled,
          version: rawVersion is num ? rawVersion.toInt() : 0,
        ),
      );
    }
    return evaluations;
  }
}
