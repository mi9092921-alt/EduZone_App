// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feature_flags_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(featureFlagRepository)
final featureFlagRepositoryProvider = FeatureFlagRepositoryProvider._();

final class FeatureFlagRepositoryProvider
    extends
        $FunctionalProvider<
          FeatureFlagRepository,
          FeatureFlagRepository,
          FeatureFlagRepository
        >
    with $Provider<FeatureFlagRepository> {
  FeatureFlagRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featureFlagRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$featureFlagRepositoryHash();

  @$internal
  @override
  $ProviderElement<FeatureFlagRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FeatureFlagRepository create(Ref ref) {
    return featureFlagRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FeatureFlagRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FeatureFlagRepository>(value),
    );
  }
}

String _$featureFlagRepositoryHash() =>
    r'72b5bfba159f2ff09943258fdb0f430fe5bdbc1d';

@ProviderFor(featureFlagCache)
final featureFlagCacheProvider = FeatureFlagCacheProvider._();

final class FeatureFlagCacheProvider
    extends
        $FunctionalProvider<
          FeatureFlagCache,
          FeatureFlagCache,
          FeatureFlagCache
        >
    with $Provider<FeatureFlagCache> {
  FeatureFlagCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featureFlagCacheProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$featureFlagCacheHash();

  @$internal
  @override
  $ProviderElement<FeatureFlagCache> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FeatureFlagCache create(Ref ref) {
    return featureFlagCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FeatureFlagCache value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FeatureFlagCache>(value),
    );
  }
}

String _$featureFlagCacheHash() => r'b65d51b639c6b4a69cf54d9b165ac97b3d3862dd';

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

@ProviderFor(featureFlagPrefs)
final featureFlagPrefsProvider = FeatureFlagPrefsProvider._();

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

final class FeatureFlagPrefsProvider
    extends
        $FunctionalProvider<
          SharedPreferences?,
          SharedPreferences?,
          SharedPreferences?
        >
    with $Provider<SharedPreferences?> {
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
  FeatureFlagPrefsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featureFlagPrefsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$featureFlagPrefsHash();

  @$internal
  @override
  $ProviderElement<SharedPreferences?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SharedPreferences? create(Ref ref) {
    return featureFlagPrefs(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SharedPreferences? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SharedPreferences?>(value),
    );
  }
}

String _$featureFlagPrefsHash() => r'c9e83399c0808247845c0ce4c86ef5c60ff54701';

/// Injectable clock so staleness logic is deterministically testable.
///
/// Deliberately a provider OF A FUNCTION, not of a DateTime: the notifier
/// watches this provider once (its identity is stable) but invokes the
/// returned function at every use site. Watching a DateTime-valued provider
/// here would freeze "now" at first build and permanently break the
/// staleness check the function exists to serve (caught by
/// feature_flags_provider_test before it shipped).

@ProviderFor(featureFlagClock)
final featureFlagClockProvider = FeatureFlagClockProvider._();

/// Injectable clock so staleness logic is deterministically testable.
///
/// Deliberately a provider OF A FUNCTION, not of a DateTime: the notifier
/// watches this provider once (its identity is stable) but invokes the
/// returned function at every use site. Watching a DateTime-valued provider
/// here would freeze "now" at first build and permanently break the
/// staleness check the function exists to serve (caught by
/// feature_flags_provider_test before it shipped).

final class FeatureFlagClockProvider
    extends
        $FunctionalProvider<
          DateTime Function(),
          DateTime Function(),
          DateTime Function()
        >
    with $Provider<DateTime Function()> {
  /// Injectable clock so staleness logic is deterministically testable.
  ///
  /// Deliberately a provider OF A FUNCTION, not of a DateTime: the notifier
  /// watches this provider once (its identity is stable) but invokes the
  /// returned function at every use site. Watching a DateTime-valued provider
  /// here would freeze "now" at first build and permanently break the
  /// staleness check the function exists to serve (caught by
  /// feature_flags_provider_test before it shipped).
  FeatureFlagClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featureFlagClockProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$featureFlagClockHash();

  @$internal
  @override
  $ProviderElement<DateTime Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DateTime Function() create(Ref ref) {
    return featureFlagClock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime Function()>(value),
    );
  }
}

String _$featureFlagClockHash() => r'ac6c318532165ea59942fbe344655e8fab6b5fd3';

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

@ProviderFor(FeatureFlags)
final featureFlagsProvider = FeatureFlagsProvider._();

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
final class FeatureFlagsProvider
    extends $NotifierProvider<FeatureFlags, FeatureFlagSnapshot> {
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
  FeatureFlagsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'featureFlagsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$featureFlagsHash();

  @$internal
  @override
  FeatureFlags create() => FeatureFlags();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FeatureFlagSnapshot value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FeatureFlagSnapshot>(value),
    );
  }
}

String _$featureFlagsHash() => r'c01a639ecfc8b77098255cd897099c470d3d242a';

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

abstract class _$FeatureFlags extends $Notifier<FeatureFlagSnapshot> {
  FeatureFlagSnapshot build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<FeatureFlagSnapshot, FeatureFlagSnapshot>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FeatureFlagSnapshot, FeatureFlagSnapshot>,
              FeatureFlagSnapshot,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
