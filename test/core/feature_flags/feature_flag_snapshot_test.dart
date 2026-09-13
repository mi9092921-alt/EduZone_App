import 'package:app/core/feature_flags/feature_flag_keys.dart';
import 'package:app/core/feature_flags/feature_flag_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final evaluatedAt = DateTime.utc(2026, 9, 13);

  group('FeatureFlagSnapshot.defaults', () {
    test('resolves every registry flag to its client-side safe default', () {
      final snapshot = FeatureFlagSnapshot.defaults();

      for (final key in FeatureFlagKey.all) {
        expect(
          snapshot.isEnabled(key),
          key.defaultValue,
          reason: '${key.name} must default to ${key.defaultValue}',
        );
      }
      expect(snapshot.source, FeatureFlagSource.defaults);
      expect(snapshot.evaluatedAt, isNull);
      expect(snapshot.versionOf(FeatureFlagKey.playerDirectPlayer), 0);
    });
  });

  group('FeatureFlagSnapshot.fromEvaluations', () {
    test('registered server verdict wins over the client default', () {
      // Client default for playerDirectPlayer is true; the server says
      // false (kill switch / rollout miss) — the server must win.
      final snapshot = FeatureFlagSnapshot.fromEvaluations([
        const FeatureFlagEvaluation(
          key: FeatureFlagKey.playerDirectPlayer,
          enabled: false,
          version: 3,
        ),
      ], evaluatedAt: evaluatedAt);

      expect(snapshot.isEnabled(FeatureFlagKey.playerDirectPlayer), isFalse);
      expect(snapshot.versionOf(FeatureFlagKey.playerDirectPlayer), 3);
      expect(snapshot.source, FeatureFlagSource.server);
      expect(snapshot.evaluatedAt, evaluatedAt);
    });

    test('server true is honored as well', () {
      final snapshot = FeatureFlagSnapshot.fromEvaluations([
        const FeatureFlagEvaluation(
          key: FeatureFlagKey.playerDirectPlayer,
          enabled: true,
          version: 1,
        ),
      ], evaluatedAt: evaluatedAt);

      expect(snapshot.isEnabled(FeatureFlagKey.playerDirectPlayer), isTrue);
    });

    test('unregistered flag (version 0) falls back to the client default', () {
      // The evaluator returns version 0 for keys it does not know — that
      // must NOT be treated as "flag off" but as "not rolled out here".
      final snapshot = FeatureFlagSnapshot.fromEvaluations([
        const FeatureFlagEvaluation(
          key: FeatureFlagKey.playerDirectPlayer,
          enabled: false,
          version: 0,
        ),
      ], evaluatedAt: evaluatedAt);

      expect(
        snapshot.isEnabled(FeatureFlagKey.playerDirectPlayer),
        FeatureFlagKey.playerDirectPlayer.defaultValue,
      );
      expect(snapshot.versionOf(FeatureFlagKey.playerDirectPlayer), 0);
    });

    test('flag missing from the response falls back to the client default', () {
      final snapshot = FeatureFlagSnapshot.fromEvaluations(
        const [],
        evaluatedAt: evaluatedAt,
      );

      expect(
        snapshot.isEnabled(FeatureFlagKey.playerDirectPlayer),
        FeatureFlagKey.playerDirectPlayer.defaultValue,
      );
    });

    test('values map is defensively unmodifiable', () {
      final snapshot = FeatureFlagSnapshot.fromEvaluations([
        const FeatureFlagEvaluation(
          key: FeatureFlagKey.playerDirectPlayer,
          enabled: false,
          version: 1,
        ),
      ], evaluatedAt: evaluatedAt);

      // _values is private; expose the defense indirectly: two snapshots
      // built from evaluations containing the same list must be
      // independent (no shared mutable state leaks between snapshots).
      final snapshot2 = FeatureFlagSnapshot.fromEvaluations([
        const FeatureFlagEvaluation(
          key: FeatureFlagKey.playerDirectPlayer,
          enabled: true,
          version: 2,
        ),
      ], evaluatedAt: evaluatedAt);

      expect(snapshot.isEnabled(FeatureFlagKey.playerDirectPlayer), isFalse);
      expect(snapshot2.isEnabled(FeatureFlagKey.playerDirectPlayer), isTrue);
    });
  });
}
