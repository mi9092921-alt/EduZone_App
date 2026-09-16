// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_refresh_listener.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Listens for [LessonProgressChangedEvent] (emitted by video_player when a
/// lesson's completion state changes) and invalidates this feature's own
/// resume/recent providers, so "Continue Learning" sections never show
/// stale progress after leaving the player.
///
/// Lives in the home feature (not video_player) so it can invalidate its
/// own providers without video_player importing home internals.
///
/// Eagerly subscribed by `lib/app/app_listeners.dart` at app startup.

@ProviderFor(homeRefreshListener)
final homeRefreshListenerProvider = HomeRefreshListenerProvider._();

/// Listens for [LessonProgressChangedEvent] (emitted by video_player when a
/// lesson's completion state changes) and invalidates this feature's own
/// resume/recent providers, so "Continue Learning" sections never show
/// stale progress after leaving the player.
///
/// Lives in the home feature (not video_player) so it can invalidate its
/// own providers without video_player importing home internals.
///
/// Eagerly subscribed by `lib/app/app_listeners.dart` at app startup.

final class HomeRefreshListenerProvider
    extends
        $FunctionalProvider<
          StreamSubscription<void>,
          StreamSubscription<void>,
          StreamSubscription<void>
        >
    with $Provider<StreamSubscription<void>> {
  /// Listens for [LessonProgressChangedEvent] (emitted by video_player when a
  /// lesson's completion state changes) and invalidates this feature's own
  /// resume/recent providers, so "Continue Learning" sections never show
  /// stale progress after leaving the player.
  ///
  /// Lives in the home feature (not video_player) so it can invalidate its
  /// own providers without video_player importing home internals.
  ///
  /// Eagerly subscribed by `lib/app/app_listeners.dart` at app startup.
  HomeRefreshListenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeRefreshListenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeRefreshListenerHash();

  @$internal
  @override
  $ProviderElement<StreamSubscription<void>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StreamSubscription<void> create(Ref ref) {
    return homeRefreshListener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StreamSubscription<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StreamSubscription<void>>(value),
    );
  }
}

String _$homeRefreshListenerHash() =>
    r'2218c8852d3f9c0c03534d97fc36aad5547b65f5';
