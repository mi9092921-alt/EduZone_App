import 'package:app/core/feature_flags/feature_flag_keys.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the registry contract that the canonical database evaluator and
/// `chk_feature_flags_key_format` (supabase/schema/04_constraints.sql) rely
/// on. A regression here is caught at PR time instead of as a failed
/// server-side INSERT or a silently-ignored flag row in production.
void main() {
  group('FeatureFlagKey registry', () {
    test('every server key satisfies the DB key-format constraint', () {
      for (final key in FeatureFlagKey.all) {
        expect(
          FeatureFlagKey.isValidServerKey(key.serverKey),
          isTrue,
          reason:
              '${key.name} serverKey "${key.serverKey}" violates '
              'chk_feature_flags_key_format '
              '(lowercase, [a-z][a-z0-9_]*(\\.[a-z0-9_]+)*, 2..128 chars)',
        );
      }
    });

    test('server keys are unique', () {
      final keys = FeatureFlagKey.all.map((k) => k.serverKey).toList();
      expect(keys.toSet().length, keys.length);
    });

    test('registry stays within the evaluator batch limit (100 keys)', () {
      // evaluate_feature_flags raises ERRCODE 22023 above 100 keys; the
      // repository asserts this too, but the assert is stripped in release.
      expect(FeatureFlagKey.all.length, lessThanOrEqualTo(100));
    });

    test('fromServerKey round-trips every registered key', () {
      for (final key in FeatureFlagKey.all) {
        expect(FeatureFlagKey.fromServerKey(key.serverKey), same(key));
      }
    });

    test('fromServerKey returns null for unknown keys', () {
      expect(FeatureFlagKey.fromServerKey('not_a_real.flag'), isNull);
      expect(FeatureFlagKey.fromServerKey(''), isNull);
    });

    test('isValidServerKey rejects malformed keys', () {
      // Uppercase, leading digit/underscore, empty, trailing dot,
      // double-dot, illegal characters, over-length.
      expect(FeatureFlagKey.isValidServerKey('Player.direct'), isFalse);
      expect(FeatureFlagKey.isValidServerKey('1player.direct'), isFalse);
      expect(FeatureFlagKey.isValidServerKey('_player.direct'), isFalse);
      expect(FeatureFlagKey.isValidServerKey(''), isFalse);
      expect(FeatureFlagKey.isValidServerKey('a'), isFalse); // min length 2
      expect(FeatureFlagKey.isValidServerKey('player.'), isFalse);
      expect(FeatureFlagKey.isValidServerKey('player..direct'), isFalse);
      expect(
        FeatureFlagKey.isValidServerKey('player.direct-player'),
        isFalse,
      );
      expect(FeatureFlagKey.isValidServerKey('a' * 129), isFalse);
    });

    test('server keys pin the registered server-side contract', () {
      // These strings are the rows in `public.feature_flags.key` managed in
      // the dashboard repo. They must stay dot-free (`^[a-z][a-z0-9_]*$`)
      // because the dashboard admin UI rejects dots, and renaming one here
      // without migrating the server row silently orphans the flag
      // (version 0 → client default), so a failure of this test must be
      // resolved by renaming the server row in the same change — or by
      // consciously updating both sides.
      expect(
        {for (final key in FeatureFlagKey.all) key.serverKey: key.defaultValue},
        {
          'player_direct_player': true,
          'home_resume_carousel': true,
          'player_youtube': true,
          'player_modern': true,
          'courses_downloads': true,
        },
      );
    });

    test('every flag documents its description', () {
      for (final key in FeatureFlagKey.all) {
        expect(key.description.trim(), isNotEmpty, reason: key.name);
      }
    });
  });
}
