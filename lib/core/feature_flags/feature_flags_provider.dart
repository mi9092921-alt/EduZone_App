import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/network_exception_mapper.dart';
import 'data/feature_flag_remote_ds.dart';
import 'feature_flag_cache.dart';
import 'feature_flag_keys.dart';
import 'feature_flag_snapshot.dart';

part 'feature_flags_provider.g.dart';

@Riverpod(keepAlive: true)
FeatureFlagRemoteDataSource featureFlagRepository(Ref ref) =>
    FeatureFlagRemoteDataSource();

@Riverpod(keepAlive: true)
FeatureFlagCache featureFlagCache(Ref ref) =>
    FeatureFlagCache(prefs: ref.watch(featureFlagPrefsProvider));

/// SharedPreferences is injected through a provider so the composition root
/// (main.dart) can hand in the instance `AppInitializer` bootstrapped before
/// `runApp` — core/ cannot import lib/app/ (lib/app imports core, never the
/// reverse).
///
/// The unoverridden default is `null`, NOT a throw: Riverpod 3 rethrows
/// provider build errors asynchronously, where no caller can catch them, so
/// every provider this module's graph watches must be constructible in any
/// environment. A null prefs simply disables the disk cache (safe defaults
/// and remote evaluation are unaffected).
///
/// Deliberately autoDispose (not keepAlive): it is watched by the keep-alive
/// cache provider, so it lives exactly as long as the module needs it.
@Riverpod()
SharedPreferences? featureFlagPrefs(Ref ref) => null;

/// Injectable clock so staleness logic is deterministically testable.
///
/// Deliberately a provider OF A FUNCTION, not of a DateTime: the notifier
/// watches this provider once (its identity is stable) but invokes the
/// returned function at every use site. Watching a DateTime-valued provider
/// here would freeze "now" at first build and permanently break the
/// staleness check the function exists to serve (caught by
/// feature_flags_provider_test before it shipped).
@Riverpod()
DateTime Function() featureFlagClock(Ref ref) => DateTime.now;

/// Runtime state of the feature-flag module: a synchronously readable
/// [FeatureFlagSnapshot], kept alive for the whole app session.
///
/// Lifecycle contract (docs/FEATURE_FLAGS.md "Startup & lifecycle"):
///
/// * build() — synchronous, never blocks startup. Serves the current
///   user's cached snapshot if fresh, else safe defaults. No network here.
/// * refresh() — called by the auth flow right after a session becomes
///   authenticated (login, cold-start restore, verifyAccess) and on app
///   resume when the snapshot is stale. A server response replaces the
///   state atomically; any failure keeps the previous snapshot.
/// * sign-out — the provider is invalidated via
///   `invalidateAllUserScopedProviders` (lib/app/session/), so the next
///   build starts from defaults (or the *new* user's cache) and can never
///   leak the previous account's flags.
///
/// Concurrency: at most one fetch in flight (concurrent callers share the
/// same future); a generation counter discards results that were
/// superseded by invalidation while the fetch was in flight.
@Riverpod(keepAlive: true)
class FeatureFlags extends _$FeatureFlags {
  Future<void>? _inFlight;
  int _generation = 0;
  bool _lifecycleWired = false;

  @override
  FeatureFlagSnapshot build() {
    _wireLifecycleListener();

    final repository = ref.watch(featureFlagRepositoryProvider);
    final cache = ref.watch(featureFlagCacheProvider);
    final clock = ref.watch(featureFlagClockProvider);

    // Synchronous, offline-safe initialization: last known server verdicts
    // for THIS user within the cache's freshness window, else defaults.
    // Never a network call — startup and first frame cannot be delayed.
    final cached = cache.load(repository.currentUserId, now: clock());
    return cached ?? FeatureFlagSnapshot.defaults();
  }

  /// Re-evaluates every registry flag server-side and replaces the state.
  ///
  /// Failure-safe by design: on any error the current snapshot is kept and
  /// the error is logged (transient connectivity noise stays out of Sentry;
  /// unexpected contract/bug-class errors are reported through Sentry,
  /// mirroring [GlobalErrorHandler]'s classification, which lives in
  /// shared/ and is therefore not importable from core/). Concurrent calls
  /// coalesce into one fetch.
  Future<void> refresh() {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final completer = Completer<void>();
    _inFlight = completer.future;
    _runRefresh().whenComplete(() {
      _inFlight = null;
      completer.complete();
    });
    return completer.future;
  }

  /// Resume/foreground hook: refresh only when the snapshot is older than
  /// [maxAge] (or was never server-evaluated). Bounds the window during
  /// which a long-lived background session could keep serving a verdict a
  /// server-side kill switch has since revoked.
  Future<void> refreshIfStale({
    Duration maxAge = const Duration(minutes: 30),
  }) {
    final evaluatedAt = state.evaluatedAt;
    final isStale = evaluatedAt == null ||
        ref.read(featureFlagClockProvider)().difference(evaluatedAt) > maxAge;
    if (!isStale) return Future.value();
    return refresh();
  }

  Future<void> _runRefresh() async {
    final generation = ++_generation;
    final stopwatch = Stopwatch()..start();

    // Everything below is inside the try: this method is invoked
    // fire-and-forget, so even resolving its own dependencies (which can
    // throw while the backend layer is unavailable, e.g. unit-test
    // containers without an initialized Supabase) must never surface an
    // unhandled async error to the caller or the zone.
    try {
      final repository = ref.read(featureFlagRepositoryProvider);
      final cache = ref.read(featureFlagCacheProvider);
      final clock = ref.read(featureFlagClockProvider);

      // The verdicts returned by the evaluator belong to the session that
      // requested them (targeting is derived server-side from THAT JWT).
      // Captured up front: if the session changes while the fetch is in
      // flight (logout, passive revocation, account switch), the result
      // must be discarded — not written into state, not persisted for
      // anyone.
      final sessionUserId = repository.currentUserId;

      final evaluations = await repository.evaluate(FeatureFlagKey.all);

      // The provider may have been invalidated (sign-out) while the fetch
      // was in flight, and the session it was issued for may be gone.
      if (generation != _generation || !ref.mounted) return;
      if (repository.currentUserId != sessionUserId) return;

      final snapshot = FeatureFlagSnapshot.fromEvaluations(
        evaluations,
        evaluatedAt: clock(),
      );
      state = snapshot;
      debugPrint(
        '[FeatureFlags] refreshed: ${snapshot.versions.length}'
        '/${FeatureFlagKey.all.length} registered flags '
        'in ${stopwatch.elapsedMilliseconds}ms',
      );

      // Best-effort persistence for the next cold start; never blocks the
      // in-memory snapshot from being consumed. Saved under the session
      // that produced the verdicts, never re-read post-await.
      unawaited(
        cache.save(sessionUserId, snapshot).catchError((Object e) {
          debugPrint('[FeatureFlags] cache save failed: ${e.runtimeType}');
        }),
      );
    } catch (e, st) {
      // Keep the previous snapshot — a failed refresh must never degrade
      // flags to defaults mid-session (defaults mean "server has never
      // spoken", not "server temporarily unreachable").
      final mapped = NetworkExceptionMapper.map(e);
      debugPrint(
        '[FeatureFlags] refresh failed (${mapped.code ?? e.runtimeType}) '
        'after ${stopwatch.elapsedMilliseconds}ms — keeping previous '
        'snapshot (source: ${state.source.name})',
      );
      if (!NetworkExceptionMapper.isRetryable(mapped)) {
        // Not connectivity/timeout → a real contract or bug-class failure
        // (missing grant, renamed RPC, unexpected payload). Same rule
        // GlobalErrorHandler applies at the uncaught-error funnel.
        try {
          unawaited(Sentry.captureException(e, stackTrace: st));
        } catch (_) {
          // Sentry not initialized (tests / no DSN) — safe no-op.
        }
      }
    }
  }

  /// Refreshes the snapshot when the app returns to the foreground, so a
  /// kill switch flipped while the app sat in the background applies on
  /// resume. Registered once per provider instance; disposed on invalidate.
  void _wireLifecycleListener() {
    if (_lifecycleWired) return;
    _lifecycleWired = true;

    // Fully guarded: a failure here (e.g. an environment without a widget
    // binding) must degrade to "no resume refresh", never to a provider
    // build error — Riverpod rethrows those asynchronously where no caller
    // can catch them.
    try {
      final listener = AppLifecycleListener(
        onResume: () {
          unawaited(
            refreshIfStale().catchError((Object e) {
              debugPrint(
                '[FeatureFlags] resume refresh failed: ${e.runtimeType}',
              );
            }),
          );
        },
      );
      ref.onDispose(listener.dispose);
    } catch (e) {
      debugPrint(
        '[FeatureFlags] lifecycle listener unavailable: ${e.runtimeType}',
      );
    }
  }
}
