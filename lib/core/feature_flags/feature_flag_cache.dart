import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'feature_flag_keys.dart';
import 'feature_flag_snapshot.dart';

/// Local availability cache for feature-flag snapshots.
///
/// Policy (docs/FEATURE_FLAGS.md "Cache behavior"):
///
/// * The server evaluator is the SOURCE OF TRUTH. This cache exists only so
///   a cold start offline (or a slow first fetch) serves the last known
///   verdicts instead of dropping every flag to defaults.
/// * It is UI configuration, not a secret — deliberately stored in
///   SharedPreferences (the app's non-sensitive prefs store), NOT in
///   flutter_secure_storage, and never contains tokens or credentials.
/// * Keyed by user id: one account's snapshot is never served to another
///   (account-isolation rule, same rationale as OfflineAccountGuard).
/// * Schema-versioned and self-validating: any payload that fails to parse,
///   has the wrong schema version, or contains unknown/invalid flag data is
///   discarded (→ safe defaults) instead of partially applied.
/// * Stale beyond [maxAge] is discarded: a kill switch flipped server-side
///   can never be overridden by old cached `true` values for longer than
///   that window, and even within the window only while the device is
///   offline (any successful refresh replaces the snapshot).
class FeatureFlagCache {
  /// [prefs] is nullable by design: the composition root (main.dart)
  /// injects the real bootstrapped instance, and environments without that
  /// wiring (unit tests) get a cache that is silently DISABLED rather than
  /// one whose provider graph throws — a missing cache only costs
  /// offline cold-start freshness, never correctness.
  FeatureFlagCache({required SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  bool get _enabled => _prefs != null;

  /// How long a cached snapshot may be served before it is treated as
  /// stale and discarded in favor of safe defaults. Long enough to cover
  /// a normal offline session, short enough to bound kill-switch latency.
  static const Duration maxAge = Duration(hours: 24);

  /// Bump when the on-disk payload shape changes incompatibly; older
  /// payloads are then discarded wholesale on next load.
  static const int _schemaVersion = 1;

  static String _storageKey(String userId) => 'feature_flags_cache_v1_$userId';

  /// Loads the cached snapshot for [userId], or null when there is no
  /// usable cache (disabled storage, missing, other user, corrupted, wrong
  /// schema, stale).
  FeatureFlagSnapshot? load(String? userId, {DateTime? now}) {
    final prefs = _prefs;
    if (prefs == null || userId == null || userId.isEmpty) return null;
    final raw = prefs.getString(_storageKey(userId));
    if (raw == null) return null;

    final effectiveNow = now ?? DateTime.now();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['v'] != _schemaVersion) return null;

      final evaluatedAtMs = decoded['evaluatedAtMs'];
      if (evaluatedAtMs is! int) return null;
      final evaluatedAt = DateTime.fromMillisecondsSinceEpoch(evaluatedAtMs);
      if (effectiveNow.difference(evaluatedAt) > maxAge) return null;

      final flags = decoded['flags'];
      if (flags is! Map<String, dynamic>) return null;

      final values = <FeatureFlagKey, bool>{};
      final versions = <FeatureFlagKey, int>{};
      final storedVersions = decoded['versions'];
      final versionMap = storedVersions is Map<String, dynamic>
          ? storedVersions
          : const <String, dynamic>{};
      flags.forEach((serverKey, rawEnabled) {
        final key = FeatureFlagKey.fromServerKey(serverKey);
        // A payload written by a NEWER app version may contain keys this
        // build does not know — skip them; unknown keys must never enter
        // the snapshot.
        if (key == null) return;
        if (rawEnabled is! bool) return;
        values[key] = rawEnabled;

        final rawVersion = versionMap[serverKey];
        if (rawVersion is int && rawVersion >= 1) {
          versions[key] = rawVersion;
        }
      });

      return FeatureFlagSnapshot(
        values: values,
        versions: versions,
        source: FeatureFlagSource.cache,
        evaluatedAt: evaluatedAt,
      );
    } on FormatException {
      // Corrupted JSON → discard entirely; safe defaults apply.
      return null;
    }
  }

  /// True when the disk cache is operational (storage injected).
  bool get isEnabled => _enabled;

  /// Persists [snapshot] for [userId]. Best-effort storage of non-critical
  /// configuration: callers treat a save failure as a no-op.
  Future<void> save(String? userId, FeatureFlagSnapshot snapshot) async {
    final prefs = _prefs;
    if (prefs == null || userId == null || userId.isEmpty) return;
    final evaluatedAt = snapshot.evaluatedAt;
    if (snapshot.source != FeatureFlagSource.server || evaluatedAt == null) {
      // Only server-verified verdicts may enter the cache — never defaults
      // (that would masquerade as an evaluation) and never a re-cached copy
      // of the cache itself.
      return;
    }

    final payload = jsonEncode({
      'v': _schemaVersion,
      'evaluatedAtMs': evaluatedAt.millisecondsSinceEpoch,
      'flags': {
        for (final entry in snapshot.versions.entries)
          entry.key.serverKey: snapshot.isEnabled(entry.key),
      },
      'versions': {
        for (final entry in snapshot.versions.entries)
          entry.key.serverKey: entry.value,
      },
    });

    await prefs.setString(_storageKey(userId), payload);
  }
}
