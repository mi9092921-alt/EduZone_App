// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Derives [AppAuthState] from the sealed [AuthState] hierarchy.
///
/// This is the ONLY provider the router watches. All 7 AppAuthState
/// values are now reachable — fixing the dead-branch router bug.

@ProviderFor(appState)
final appStateProvider = AppStateProvider._();

/// Derives [AppAuthState] from the sealed [AuthState] hierarchy.
///
/// This is the ONLY provider the router watches. All 7 AppAuthState
/// values are now reachable — fixing the dead-branch router bug.

final class AppStateProvider
    extends $FunctionalProvider<AppAuthState, AppAuthState, AppAuthState>
    with $Provider<AppAuthState> {
  /// Derives [AppAuthState] from the sealed [AuthState] hierarchy.
  ///
  /// This is the ONLY provider the router watches. All 7 AppAuthState
  /// values are now reachable — fixing the dead-branch router bug.
  AppStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appStateHash();

  @$internal
  @override
  $ProviderElement<AppAuthState> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppAuthState create(Ref ref) {
    return appState(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppAuthState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppAuthState>(value),
    );
  }
}

String _$appStateHash() => r'81893b42ac6c0ba198c81269768f3b90a573e82f';
