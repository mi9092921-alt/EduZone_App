import 'dart:async';

import 'package:app/core/feature_flags/feature_flag_cache.dart';
import 'package:app/core/feature_flags/feature_flag_keys.dart';
import 'package:app/core/feature_flags/feature_flag_repository.dart';
import 'package:app/core/feature_flags/feature_flag_snapshot.dart';
import 'package:app/core/feature_flags/feature_flags_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFeatureFlagRepository extends Mock implements FeatureFlagRepository {}

class MockFeatureFlagCache extends Mock implements FeatureFlagCache {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(<FeatureFlagKey>[]);
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(FeatureFlagSnapshot.defaults());
  });

  final baseTime = DateTime.utc(2026, 9, 13, 12);

  final serverVerdict = [
    const FeatureFlagEvaluation(
      key: FeatureFlagKey.playerDirectPlayer,
      enabled: false,
      version: 9,
    ),
  ];

  late MockFeatureFlagRepository repository;
  late MockFeatureFlagCache cache;
  late DateTime Function() clock;
  late ProviderContainer container;

  ProviderContainer buildContainer() {
    return ProviderContainer(
      overrides: [
        featureFlagRepositoryProvider.overrideWithValue(repository),
        featureFlagCacheProvider.overrideWithValue(cache),
        featureFlagClockProvider.overrideWithValue(() => clock()),
        featureFlagPrefsProvider.overrideWithValue(_UnusedPrefs.instance),
      ],
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = MockFeatureFlagRepository();
    cache = MockFeatureFlagCache();
    clock = () => baseTime;

    when(() => repository.currentUserId).thenReturn(null);
    when(() => repository.evaluate(any()))
        .thenAnswer((_) async => const []);
    when(() => cache.load(any(), now: any(named: 'now'))).thenReturn(null);
    when(() => cache.save(any(), any())).thenAnswer((_) async {});

    container = buildContainer();
    addTearDown(container.dispose);
  });

  FeatureFlagSnapshot state() => container.read(featureFlagsProvider);

  group('initial state (build)', () {
    test('signed out → safe defaults, source=defaults', () {
      when(() => repository.currentUserId).thenReturn(null);

      expect(state().source, FeatureFlagSource.defaults);
      expect(
        state().isEnabled(FeatureFlagKey.playerDirectPlayer),
        FeatureFlagKey.playerDirectPlayer.defaultValue,
      );
      // No network during build — evaluate must never have been called.
      verifyNever(() => repository.evaluate(any()));
    });

    test('fresh cache for the current user is served synchronously',
        () {
      when(() => repository.currentUserId).thenReturn('user-1');
      final cached = FeatureFlagSnapshot(
        values: const {FeatureFlagKey.playerDirectPlayer: false},
        versions: const {FeatureFlagKey.playerDirectPlayer: 9},
        source: FeatureFlagSource.cache,
        evaluatedAt: baseTime.subtract(const Duration(minutes: 5)),
      );
      when(() => cache.load('user-1', now: any(named: 'now')))
          .thenReturn(cached);

      // Rebuild with the cache-bearing setup.
      container = buildContainer();
      addTearDown(container.dispose);

      expect(state().source, FeatureFlagSource.cache);
      expect(state().isEnabled(FeatureFlagKey.playerDirectPlayer), isFalse);
      verifyNever(() => repository.evaluate(any()));
    });

    test('corrupted/stale cache (load → null) degrades to defaults', () {
      when(() => repository.currentUserId).thenReturn('user-1');
      when(() => cache.load('user-1', now: any(named: 'now'))).thenReturn(null);

      expect(state().source, FeatureFlagSource.defaults);
    });
  });

  group('refresh', () {
    test('success replaces state with the server snapshot and persists it',
        () async {
      when(() => repository.currentUserId).thenReturn('user-1');
      when(() => repository.evaluate(any())).thenAnswer((_) async => [
            ...serverVerdict,
          ]);

      await container.read(featureFlagsProvider.notifier).refresh();

      expect(state().source, FeatureFlagSource.server);
      expect(state().isEnabled(FeatureFlagKey.playerDirectPlayer), isFalse);
      expect(state().evaluatedAt, baseTime);

      final saved = verify(
        () => cache.save('user-1', captureAny()),
      ).captured.single as FeatureFlagSnapshot;
      expect(saved.source, FeatureFlagSource.server);
    });

    test('unregistered flag (version 0) keeps the client default', () async {
      when(() => repository.evaluate(any())).thenAnswer((_) async => [
            const FeatureFlagEvaluation(
              key: FeatureFlagKey.playerDirectPlayer,
              enabled: false,
              version: 0,
            ),
          ]);

      await container.read(featureFlagsProvider.notifier).refresh();

      expect(
        state().isEnabled(FeatureFlagKey.playerDirectPlayer),
        FeatureFlagKey.playerDirectPlayer.defaultValue,
      );
    });

    test('retryable failure keeps the previous snapshot', () async {
      when(() => repository.evaluate(any())).thenAnswer((_) async =>
          [...serverVerdict]);
      await container.read(featureFlagsProvider.notifier).refresh();
      final before = state();

      when(() => repository.evaluate(any())).thenThrow(
        TimeoutException('stalled'),
      );
      await container.read(featureFlagsProvider.notifier).refresh();

      expect(state(), same(before));
      expect(state().source, FeatureFlagSource.server);
    });

    test('non-retryable failure keeps the previous snapshot too', () async {
      when(() => repository.evaluate(any())).thenAnswer(
        (_) async => [...serverVerdict],
      );
      await container.read(featureFlagsProvider.notifier).refresh();

      when(() => repository.evaluate(any())).thenThrow(
        const PostgrestLikeException(),
      );
      await container.read(featureFlagsProvider.notifier).refresh();

      expect(state().source, FeatureFlagSource.server);
      expect(state().isEnabled(FeatureFlagKey.playerDirectPlayer), isFalse);
    });

    test('concurrent refreshes coalesce into one fetch', () async {
      final gate = Completer<List<FeatureFlagEvaluation>>();
      when(() => repository.evaluate(any()))
          .thenAnswer((_) => gate.future);

      final notifier = container.read(featureFlagsProvider.notifier);
      final f1 = notifier.refresh();
      final f2 = notifier.refresh();

      // Both callers are waiting on the SAME in-flight fetch.
      expect(identical(f1, f2), isTrue);

      gate.complete([...serverVerdict]);
      await Future.wait([f1, f2]);

      verify(() => repository.evaluate(any())).called(1);
    });

    test('a refresh after completion fetches again (no sticky dedup)',
        () async {
      when(() => repository.evaluate(any()))
          .thenAnswer((_) async => [...serverVerdict]);

      final notifier = container.read(featureFlagsProvider.notifier);
      await notifier.refresh();
      await notifier.refresh();

      verify(() => repository.evaluate(any())).called(2);
    });
  });

  group('refreshIfStale', () {
    test('fresh snapshot (≤ maxAge) does not fetch', () async {
      when(() => repository.evaluate(any()))
          .thenAnswer((_) async => [...serverVerdict]);
      await container.read(featureFlagsProvider.notifier).refresh();

      await container.read(featureFlagsProvider.notifier).refreshIfStale();

      verify(() => repository.evaluate(any())).called(1);
    });

    test('snapshot older than maxAge triggers a refresh', () async {
      var now = baseTime;
      clock = () => now;
      when(() => repository.evaluate(any()))
          .thenAnswer((_) async => [...serverVerdict]);
      await container.read(featureFlagsProvider.notifier).refresh();

      now = baseTime.add(const Duration(minutes: 31));
      await container.read(featureFlagsProvider.notifier).refreshIfStale();

      verify(() => repository.evaluate(any())).called(2);
    });
  });

  group('sign-out invalidation', () {
    test('invalidate rebuilds from defaults when no session remains',
        () async {
      when(() => repository.currentUserId).thenReturn('user-1');
      when(() => repository.evaluate(any()))
          .thenAnswer((_) async => [...serverVerdict]);
      await container.read(featureFlagsProvider.notifier).refresh();
      expect(state().source, FeatureFlagSource.server);

      // Logout path: session gone + provider invalidated (exactly what
      // invalidateAllUserScopedProviders does).
      when(() => repository.currentUserId).thenReturn(null);
      container.invalidate(featureFlagsProvider);

      expect(state().source, FeatureFlagSource.defaults);
      expect(
        state().isEnabled(FeatureFlagKey.playerDirectPlayer),
        FeatureFlagKey.playerDirectPlayer.defaultValue,
      );
    });

    test('an in-flight refresh for a torn-down session writes nothing',
        () async {
      when(() => repository.currentUserId).thenReturn('user-1');
      final gate = Completer<List<FeatureFlagEvaluation>>();
      when(() => repository.evaluate(any())).thenAnswer((_) => gate.future);

      final refreshFuture =
          container.read(featureFlagsProvider.notifier).refresh();

      // Logout happens while the fetch is in flight.
      when(() => repository.currentUserId).thenReturn(null);
      container.invalidate(featureFlagsProvider);

      gate.complete([...serverVerdict]);
      await refreshFuture;
      await pumpEventQueue();

      // The stale result must not have been written to the (new) state or
      // persisted under any user.
      expect(state().source, FeatureFlagSource.defaults);
      verifyNever(() => cache.save(any(), any()));
    });
  });
}

/// PostgrestException cannot be const-constructed without going through its
/// factory (which requires code from the supabase package's internals); this
/// stand-in exercises the non-retryable classification path — which keys off
/// `NetworkExceptionMapper.map`'s fallback ServerException, not the concrete
/// type.
class PostgrestLikeException implements Exception {
  const PostgrestLikeException();
}

/// Type-safe placeholder so the prefs provider override satisfies the
/// overrideWithValue signature without the real SharedPreferences mock —
/// the cache is fully mocked in these tests and never touches prefs.
class _UnusedPrefs implements SharedPreferences {
  static final SharedPreferences instance = _UnusedPrefs();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
