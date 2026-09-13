import 'dart:convert';

import 'package:app/core/feature_flags/feature_flag_cache.dart';
import 'package:app/core/feature_flags/feature_flag_keys.dart';
import 'package:app/core/feature_flags/feature_flag_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const userId = 'user-1';
  final evaluatedAt = DateTime.utc(2026, 9, 13, 12);
  late FeatureFlagCache cache;

  FeatureFlagSnapshot serverSnapshot({bool enabled = true, int version = 4}) {
    return FeatureFlagSnapshot.fromEvaluations(
      [
        FeatureFlagEvaluation(
          key: FeatureFlagKey.playerDirectPlayer,
          enabled: enabled,
          version: version,
        ),
      ],
      evaluatedAt: evaluatedAt,
    );
  }

  /// Each test builds its own SharedPreferences-backed cache. The mock
  /// initial values must be set BEFORE the first `getInstance()` — the
  /// singleton caches whatever it first saw, so per-test payloads have to
  /// be in place up front.
  Future<FeatureFlagCache> makeCache([
    Map<String, Object> initial = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    return FeatureFlagCache(prefs: await SharedPreferences.getInstance());
  }

  String payload({
    Object? flags = const {'player.direct_player': true},
    Object? versions = const {'player.direct_player': 2},
    int? evaluatedAtMs,
    Object? schemaVersion = 1,
  }) {
    return jsonEncode({
      'v': schemaVersion,
      'evaluatedAtMs': evaluatedAtMs ?? evaluatedAt.millisecondsSinceEpoch,
      'flags': flags,
      'versions': versions,
    });
  }

  group('save/load round-trip', () {
    setUp(() async {
      cache = await makeCache();
    });

    test('a server snapshot survives save → load with values intact',
        () async {
      await cache.save(userId, serverSnapshot(enabled: false));

      final loaded = cache.load(userId);

      expect(loaded, isNotNull);
      expect(loaded!.source, FeatureFlagSource.cache);
      expect(loaded.isEnabled(FeatureFlagKey.playerDirectPlayer), isFalse);
      expect(loaded.versionOf(FeatureFlagKey.playerDirectPlayer), 4);
      expect(loaded.evaluatedAt!.isAtSameMomentAs(evaluatedAt), isTrue);
    });

    test('cache is keyed per user — one account never sees another',
        () async {
      await cache.save(userId, serverSnapshot());

      // Same device, different account: no snapshot may leak across.
      expect(cache.load('user-2'), isNull);
      expect(cache.load(null), isNull);
      expect(cache.load(''), isNull);
      expect(cache.load(userId), isNotNull);
    });

    test('save with no user is a no-op (no unkeyed blobs)', () async {
      await cache.save(null, serverSnapshot());
      expect(cache.load(null), isNull);
    });

    test('a snapshot stays available for its own user across sign-out',
        () async {
      // Deliberate policy: the disk cache is user-keyed and NON-sensitive
      // (UI booleans only), so it intentionally survives sign-out to serve
      // the same user's offline cold start after re-login. Cross-account
      // isolation is guaranteed by the key, not by deletion.
      await cache.save(userId, serverSnapshot());
      expect(cache.load(userId), isNotNull);
    });
  });

  group('cache admission policy', () {
    setUp(() async {
      cache = await makeCache();
    });

    test('defaults snapshots are never cached', () async {
      await cache.save(userId, FeatureFlagSnapshot.defaults());
      expect(cache.load(userId), isNull);
    });

    test('a re-saved cache snapshot is not re-cached', () async {
      // save() only admits server-sourced snapshots, so load() → save()
      // must not create a self-perpetuating snapshot with a fresh
      // timestamp masquerading as an evaluation.
      await cache.save(userId, serverSnapshot());
      final loaded = cache.load(userId)!;
      await cache.save(userId, loaded);
      // Still the ORIGINAL evaluation timestamp, not save-time.
      expect(
        cache.load(userId)!.evaluatedAt!.isAtSameMomentAs(evaluatedAt),
        isTrue,
      );
    });
  });

  group('corruption & schema handling', () {
    test('corrupted JSON is discarded → null (safe defaults apply)',
        () async {
      cache = await makeCache({
        'feature_flags_cache_v1_$userId': '{not valid json!!',
      });
      expect(cache.load(userId), isNull);
    });

    test('wrong schema version is discarded', () async {
      cache = await makeCache({
        'feature_flags_cache_v1_$userId':
            payload(schemaVersion: 999),
      });
      expect(cache.load(userId), isNull);
    });

    test('non-map payload is discarded', () async {
      cache = await makeCache({
        'feature_flags_cache_v1_$userId': jsonEncode(['array']),
      });
      expect(cache.load(userId), isNull);
    });

    test('unknown flag keys from a newer app version are skipped', () async {
      cache = await makeCache({
        'feature_flags_cache_v1_$userId': payload(
          flags: {
            'player.direct_player': true,
            'future.feature': true, // unknown to this build
            'malformed': 'not-a-bool',
          },
        ),
      });

      final loaded = cache.load(userId);

      expect(loaded, isNotNull);
      expect(loaded!.isEnabled(FeatureFlagKey.playerDirectPlayer), isTrue);
      // Unknown keys do not enter the snapshot: they resolve to defaults.
      expect(
        loaded.versions
            .containsKey(FeatureFlagKey.fromServerKey('future.feature')),
        isFalse,
      );
    });
  });

  group('staleness policy', () {
    test('fresh cache (within 24h) is served', () async {
      cache = await makeCache({
        'feature_flags_cache_v1_$userId': payload(),
      });

      final loaded = cache.load(
        userId,
        now: evaluatedAt.add(const Duration(hours: 23)),
      );
      expect(loaded, isNotNull);
    });

    test('cache older than 24h is discarded (stale true never served)',
        () async {
      cache = await makeCache({
        'feature_flags_cache_v1_$userId': payload(),
      });

      // A kill switch flipped 25h ago must not be overridden by this
      // cached value any longer.
      final loaded = cache.load(
        userId,
        now: evaluatedAt.add(const Duration(hours: 25)),
      );
      expect(loaded, isNull);
    });
  });
}
