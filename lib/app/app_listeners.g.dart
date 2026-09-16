// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_listeners.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Composition root for event-bus listeners that must be subscribed for the
/// whole app lifetime, regardless of which screen is visible.
///
/// Eagerly watched by [EduZoneApp.build] (same bootstrap pattern as
/// `eventDispatcherProvider`). Each listener owns its subscription lifecycle
/// via `ref.onDispose` and may only touch its own feature's internals —
/// cross-feature communication flows through the [EventBus], never through
/// direct feature-to-feature imports.

@ProviderFor(appListeners)
final appListenersProvider = AppListenersProvider._();

/// Composition root for event-bus listeners that must be subscribed for the
/// whole app lifetime, regardless of which screen is visible.
///
/// Eagerly watched by [EduZoneApp.build] (same bootstrap pattern as
/// `eventDispatcherProvider`). Each listener owns its subscription lifecycle
/// via `ref.onDispose` and may only touch its own feature's internals —
/// cross-feature communication flows through the [EventBus], never through
/// direct feature-to-feature imports.

final class AppListenersProvider extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Composition root for event-bus listeners that must be subscribed for the
  /// whole app lifetime, regardless of which screen is visible.
  ///
  /// Eagerly watched by [EduZoneApp.build] (same bootstrap pattern as
  /// `eventDispatcherProvider`). Each listener owns its subscription lifecycle
  /// via `ref.onDispose` and may only touch its own feature's internals —
  /// cross-feature communication flows through the [EventBus], never through
  /// direct feature-to-feature imports.
  AppListenersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appListenersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appListenersHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return appListeners(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$appListenersHash() => r'31d208015b1a7603126643727a52f6a6d66d7b71';
