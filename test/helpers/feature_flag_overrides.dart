import 'package:app/core/feature_flags/feature_flag_keys.dart';
import 'package:app/core/feature_flags/feature_flag_snapshot.dart';
import 'package:app/core/feature_flags/feature_flags_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

/// Builds an override pinning [featureFlagsProvider] to a server-sourced
/// snapshot with the given verdicts, so widget tests can simulate any
/// kill-switch state without the network path.
///
/// Keys absent from [values] resolve to their client defaults (current
/// behavior) via [FeatureFlagSnapshot.isEnabled].
Override featureFlagsOverride([
  Map<FeatureFlagKey, bool> values = const {},
]) {
  return featureFlagsProvider.overrideWithValue(
    FeatureFlagSnapshot(
      values: values,
      source: FeatureFlagSource.server,
      evaluatedAt: DateTime(2026),
    ),
  );
}
