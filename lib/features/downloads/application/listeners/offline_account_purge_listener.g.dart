// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_account_purge_listener.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Listens for [AuthLoginEvent] and purges local downloads left behind by
/// a *different* account that was previously signed into this device
/// (P6.20 "Account Switching" — see [OfflineAccountGuard]).
///
/// This listener lives in the downloads feature so the guard's dependencies
/// (local data source + encryption service) are resolved from downloads' own
/// DI providers; auth only emits the login event on the [EventBus] and never
/// imports downloads internals. Best-effort, fire-and-forget — must never
/// block or fail login. (Playback of another account's downloads is already
/// independently denied by OfflinePolicyEngine even if this purge is delayed
/// or fails.)
///
/// Eagerly subscribed by `lib/app/app_listeners.dart` at app startup.

@ProviderFor(offlineAccountPurgeListener)
final offlineAccountPurgeListenerProvider =
    OfflineAccountPurgeListenerProvider._();

/// Listens for [AuthLoginEvent] and purges local downloads left behind by
/// a *different* account that was previously signed into this device
/// (P6.20 "Account Switching" — see [OfflineAccountGuard]).
///
/// This listener lives in the downloads feature so the guard's dependencies
/// (local data source + encryption service) are resolved from downloads' own
/// DI providers; auth only emits the login event on the [EventBus] and never
/// imports downloads internals. Best-effort, fire-and-forget — must never
/// block or fail login. (Playback of another account's downloads is already
/// independently denied by OfflinePolicyEngine even if this purge is delayed
/// or fails.)
///
/// Eagerly subscribed by `lib/app/app_listeners.dart` at app startup.

final class OfflineAccountPurgeListenerProvider
    extends
        $FunctionalProvider<
          StreamSubscription<void>,
          StreamSubscription<void>,
          StreamSubscription<void>
        >
    with $Provider<StreamSubscription<void>> {
  /// Listens for [AuthLoginEvent] and purges local downloads left behind by
  /// a *different* account that was previously signed into this device
  /// (P6.20 "Account Switching" — see [OfflineAccountGuard]).
  ///
  /// This listener lives in the downloads feature so the guard's dependencies
  /// (local data source + encryption service) are resolved from downloads' own
  /// DI providers; auth only emits the login event on the [EventBus] and never
  /// imports downloads internals. Best-effort, fire-and-forget — must never
  /// block or fail login. (Playback of another account's downloads is already
  /// independently denied by OfflinePolicyEngine even if this purge is delayed
  /// or fails.)
  ///
  /// Eagerly subscribed by `lib/app/app_listeners.dart` at app startup.
  OfflineAccountPurgeListenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineAccountPurgeListenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineAccountPurgeListenerHash();

  @$internal
  @override
  $ProviderElement<StreamSubscription<void>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StreamSubscription<void> create(Ref ref) {
    return offlineAccountPurgeListener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StreamSubscription<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StreamSubscription<void>>(value),
    );
  }
}

String _$offlineAccountPurgeListenerHash() =>
    r'c117aea68457853e3b94f334c9e89e6a31f87053';
