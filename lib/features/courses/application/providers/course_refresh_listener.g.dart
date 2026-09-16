// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_refresh_listener.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Listens for [LessonProgressChangedEvent] (emitted by video_player when a
/// lesson's completion state changes) and invalidates this feature's own
/// progress providers, so course progress never shows stale data after
/// leaving the player.
///
/// Lives in the courses feature (not video_player) so it can invalidate its
/// own providers without video_player importing courses internals.
///
/// Eagerly subscribed by `lib/app/app_listeners.dart` at app startup.

@ProviderFor(courseRefreshListener)
final courseRefreshListenerProvider = CourseRefreshListenerProvider._();

/// Listens for [LessonProgressChangedEvent] (emitted by video_player when a
/// lesson's completion state changes) and invalidates this feature's own
/// progress providers, so course progress never shows stale data after
/// leaving the player.
///
/// Lives in the courses feature (not video_player) so it can invalidate its
/// own providers without video_player importing courses internals.
///
/// Eagerly subscribed by `lib/app/app_listeners.dart` at app startup.

final class CourseRefreshListenerProvider
    extends
        $FunctionalProvider<
          StreamSubscription<void>,
          StreamSubscription<void>,
          StreamSubscription<void>
        >
    with $Provider<StreamSubscription<void>> {
  /// Listens for [LessonProgressChangedEvent] (emitted by video_player when a
  /// lesson's completion state changes) and invalidates this feature's own
  /// progress providers, so course progress never shows stale data after
  /// leaving the player.
  ///
  /// Lives in the courses feature (not video_player) so it can invalidate its
  /// own providers without video_player importing courses internals.
  ///
  /// Eagerly subscribed by `lib/app/app_listeners.dart` at app startup.
  CourseRefreshListenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'courseRefreshListenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$courseRefreshListenerHash();

  @$internal
  @override
  $ProviderElement<StreamSubscription<void>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StreamSubscription<void> create(Ref ref) {
    return courseRefreshListener(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StreamSubscription<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StreamSubscription<void>>(value),
    );
  }
}

String _$courseRefreshListenerHash() =>
    r'8d1b33e783c71a4d8afe9a0a807b6b59ed83e9d5';
