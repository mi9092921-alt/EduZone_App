import 'feature_flag_keys.dart';

/// Where a [FeatureFlagSnapshot]'s values came from. Ordered by increasing
/// trustworthiness — `server` is the source of truth, `cache` is an
/// availability optimization only, `defaults` is the fail-safe baseline.
enum FeatureFlagSource { defaults, cache, server }

/// One server-evaluated flag verdict.
///
/// [version] comes from the canonical `feature_flags.version` column:
/// `0` means the key is not registered server-side (unknown to the
/// evaluator's LEFT JOIN), `>= 1` means the verdict is authoritative.
class FeatureFlagEvaluation {
  const FeatureFlagEvaluation({
    required this.key,
    required this.enabled,
    required this.version,
  });

  final FeatureFlagKey key;

  /// Server verdict. Only meaningful when [version] >= 1.
  final bool enabled;

  /// 0 = flag not registered server-side; >= 1 = registered revision.
  final int version;

  /// True when the server actually knows this flag (registered row).
  bool get isRegistered => version >= 1;
}

/// Immutable, synchronously readable feature-flag state.
///
/// Consumers call [isEnabled] — never inspect the raw map — so a flag that
/// is missing from any source automatically resolves to its client-side
/// safe default instead of throwing or defaulting to false.
///
/// This snapshot is configuration for UI affordances only. It is never an
/// authorization boundary: every protected operation remains enforced
/// server-side (RLS / RPC permission checks) regardless of what this
/// object claims.
class FeatureFlagSnapshot {
  // Not a const constructor: `Map.unmodifiable` below cannot run at
  // compile time, and the defensive copy is the point — a caller-held map
  // must not be able to mutate an already-published snapshot.
  FeatureFlagSnapshot({
    required Map<FeatureFlagKey, bool> values,
    required this.source,
    this.evaluatedAt,
    this.versions = const {},
  }) : _values = Map.unmodifiable(values);

  /// The fail-safe baseline: every flag at its client-side default.
  factory FeatureFlagSnapshot.defaults() => FeatureFlagSnapshot(
        values: const {},
        source: FeatureFlagSource.defaults,
      );

  /// Builds the authoritative snapshot from repository evaluations.
  ///
  /// Resolution rule per key:
  /// * registered server row (version >= 1) → server verdict;
  /// * unregistered (version 0) or absent row → client-side default
  ///   (the flag was never rolled out to this app version).
  factory FeatureFlagSnapshot.fromEvaluations(
    List<FeatureFlagEvaluation> evaluations, {
    required DateTime evaluatedAt,
  }) {
    final values = <FeatureFlagKey, bool>{};
    final versions = <FeatureFlagKey, int>{};
    for (final evaluation in evaluations) {
      if (evaluation.isRegistered) {
        values[evaluation.key] = evaluation.enabled;
        versions[evaluation.key] = evaluation.version;
      }
      // Unregistered keys deliberately do not enter the snapshot: the
      // client default already reflects "not rolled out".
    }
    return FeatureFlagSnapshot(
      values: values,
      versions: versions,
      source: FeatureFlagSource.server,
      evaluatedAt: evaluatedAt,
    );
  }

  final Map<FeatureFlagKey, bool> _values;

  /// Per-flag server revision the values were evaluated at. Only keys the
  /// server knows appear here; used for cache diagnostics/observability.
  final Map<FeatureFlagKey, int> versions;

  final FeatureFlagSource source;

  /// When the server evaluation behind this snapshot happened (null for
  /// [FeatureFlagSource.defaults]).
  final DateTime? evaluatedAt;

  /// Resolves [key]. Order of precedence:
  /// server/cache value if present → [FeatureFlagKey.defaultValue].
  /// Never throws for an unregistered or missing flag.
  bool isEnabled(FeatureFlagKey key) => _values[key] ?? key.defaultValue;

  /// The server version for [key], or 0 when unknown/unregistered.
  int versionOf(FeatureFlagKey key) => versions[key] ?? 0;
}
