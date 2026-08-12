// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(videoPlayerRemoteDataSource)
final videoPlayerRemoteDataSourceProvider =
    VideoPlayerRemoteDataSourceProvider._();

final class VideoPlayerRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          VideoPlayerRemoteDataSource,
          VideoPlayerRemoteDataSource,
          VideoPlayerRemoteDataSource
        >
    with $Provider<VideoPlayerRemoteDataSource> {
  VideoPlayerRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoPlayerRemoteDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoPlayerRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<VideoPlayerRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoPlayerRemoteDataSource create(Ref ref) {
    return videoPlayerRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoPlayerRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoPlayerRemoteDataSource>(value),
    );
  }
}

String _$videoPlayerRemoteDataSourceHash() =>
    r'68fe21bc0a786f07f133493300736d5e192868ff';

@ProviderFor(videoPlayerRepository)
final videoPlayerRepositoryProvider = VideoPlayerRepositoryProvider._();

final class VideoPlayerRepositoryProvider
    extends
        $FunctionalProvider<
          VideoPlayerRepository,
          VideoPlayerRepository,
          VideoPlayerRepository
        >
    with $Provider<VideoPlayerRepository> {
  VideoPlayerRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoPlayerRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoPlayerRepositoryHash();

  @$internal
  @override
  $ProviderElement<VideoPlayerRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoPlayerRepository create(Ref ref) {
    return videoPlayerRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoPlayerRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoPlayerRepository>(value),
    );
  }
}

String _$videoPlayerRepositoryHash() =>
    r'023cdaa5a4c76c6ca017908d84727e718fb36c91';

@ProviderFor(syncLessonProgress)
final syncLessonProgressProvider = SyncLessonProgressProvider._();

final class SyncLessonProgressProvider
    extends
        $FunctionalProvider<
          SyncLessonProgress,
          SyncLessonProgress,
          SyncLessonProgress
        >
    with $Provider<SyncLessonProgress> {
  SyncLessonProgressProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncLessonProgressProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncLessonProgressHash();

  @$internal
  @override
  $ProviderElement<SyncLessonProgress> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SyncLessonProgress create(Ref ref) {
    return syncLessonProgress(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncLessonProgress value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncLessonProgress>(value),
    );
  }
}

String _$syncLessonProgressHash() =>
    r'57536151c5093db60034a81ec225366883354485';

/// Manages video playback progress state and debounced DB sync.
///
/// IMPORTANT: this notifier calls `ref.keepAlive()` in [build] so it is not
/// disposed the moment its last listener drops off (e.g. when the player
/// widget calls `ref.read(...)` instead of `ref.watch(...)`). Without this,
/// the provider gets auto-disposed almost immediately after creation, and
/// any subsequent use of `ref` inside `onDispose` (or anything scheduled
/// after disposal, like the debounce Timer) throws:
///   "Cannot use the Ref of videoProgressProvider(...) after it has been disposed."
///
/// All external dependencies (`SyncLessonProgress`, `VideoPlayerRepository`)
/// are resolved once during [build] and cached as fields. `_syncToDb` and
/// `_logCompletion` must NEVER call `ref.read`/`ref.watch` themselves,
/// since they can run from `onDispose` or from a Timer that fires after
/// disposal — at which point `ref` is no longer usable.

@ProviderFor(VideoProgress)
final videoProgressProvider = VideoProgressFamily._();

/// Manages video playback progress state and debounced DB sync.
///
/// IMPORTANT: this notifier calls `ref.keepAlive()` in [build] so it is not
/// disposed the moment its last listener drops off (e.g. when the player
/// widget calls `ref.read(...)` instead of `ref.watch(...)`). Without this,
/// the provider gets auto-disposed almost immediately after creation, and
/// any subsequent use of `ref` inside `onDispose` (or anything scheduled
/// after disposal, like the debounce Timer) throws:
///   "Cannot use the Ref of videoProgressProvider(...) after it has been disposed."
///
/// All external dependencies (`SyncLessonProgress`, `VideoPlayerRepository`)
/// are resolved once during [build] and cached as fields. `_syncToDb` and
/// `_logCompletion` must NEVER call `ref.read`/`ref.watch` themselves,
/// since they can run from `onDispose` or from a Timer that fires after
/// disposal — at which point `ref` is no longer usable.
final class VideoProgressProvider
    extends $NotifierProvider<VideoProgress, VideoState> {
  /// Manages video playback progress state and debounced DB sync.
  ///
  /// IMPORTANT: this notifier calls `ref.keepAlive()` in [build] so it is not
  /// disposed the moment its last listener drops off (e.g. when the player
  /// widget calls `ref.read(...)` instead of `ref.watch(...)`). Without this,
  /// the provider gets auto-disposed almost immediately after creation, and
  /// any subsequent use of `ref` inside `onDispose` (or anything scheduled
  /// after disposal, like the debounce Timer) throws:
  ///   "Cannot use the Ref of videoProgressProvider(...) after it has been disposed."
  ///
  /// All external dependencies (`SyncLessonProgress`, `VideoPlayerRepository`)
  /// are resolved once during [build] and cached as fields. `_syncToDb` and
  /// `_logCompletion` must NEVER call `ref.read`/`ref.watch` themselves,
  /// since they can run from `onDispose` or from a Timer that fires after
  /// disposal — at which point `ref` is no longer usable.
  VideoProgressProvider._({
    required VideoProgressFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'videoProgressProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$videoProgressHash();

  @override
  String toString() {
    return r'videoProgressProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  VideoProgress create() => VideoProgress();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is VideoProgressProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$videoProgressHash() => r'7b1835ad7d79011397354494277bba9787c611b0';

/// Manages video playback progress state and debounced DB sync.
///
/// IMPORTANT: this notifier calls `ref.keepAlive()` in [build] so it is not
/// disposed the moment its last listener drops off (e.g. when the player
/// widget calls `ref.read(...)` instead of `ref.watch(...)`). Without this,
/// the provider gets auto-disposed almost immediately after creation, and
/// any subsequent use of `ref` inside `onDispose` (or anything scheduled
/// after disposal, like the debounce Timer) throws:
///   "Cannot use the Ref of videoProgressProvider(...) after it has been disposed."
///
/// All external dependencies (`SyncLessonProgress`, `VideoPlayerRepository`)
/// are resolved once during [build] and cached as fields. `_syncToDb` and
/// `_logCompletion` must NEVER call `ref.read`/`ref.watch` themselves,
/// since they can run from `onDispose` or from a Timer that fires after
/// disposal — at which point `ref` is no longer usable.

final class VideoProgressFamily extends $Family
    with
        $ClassFamilyOverride<
          VideoProgress,
          VideoState,
          VideoState,
          VideoState,
          (String, String)
        > {
  VideoProgressFamily._()
    : super(
        retry: null,
        name: r'videoProgressProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Manages video playback progress state and debounced DB sync.
  ///
  /// IMPORTANT: this notifier calls `ref.keepAlive()` in [build] so it is not
  /// disposed the moment its last listener drops off (e.g. when the player
  /// widget calls `ref.read(...)` instead of `ref.watch(...)`). Without this,
  /// the provider gets auto-disposed almost immediately after creation, and
  /// any subsequent use of `ref` inside `onDispose` (or anything scheduled
  /// after disposal, like the debounce Timer) throws:
  ///   "Cannot use the Ref of videoProgressProvider(...) after it has been disposed."
  ///
  /// All external dependencies (`SyncLessonProgress`, `VideoPlayerRepository`)
  /// are resolved once during [build] and cached as fields. `_syncToDb` and
  /// `_logCompletion` must NEVER call `ref.read`/`ref.watch` themselves,
  /// since they can run from `onDispose` or from a Timer that fires after
  /// disposal — at which point `ref` is no longer usable.

  VideoProgressProvider call(String courseId, String lessonId) =>
      VideoProgressProvider._(argument: (courseId, lessonId), from: this);

  @override
  String toString() => r'videoProgressProvider';
}

/// Manages video playback progress state and debounced DB sync.
///
/// IMPORTANT: this notifier calls `ref.keepAlive()` in [build] so it is not
/// disposed the moment its last listener drops off (e.g. when the player
/// widget calls `ref.read(...)` instead of `ref.watch(...)`). Without this,
/// the provider gets auto-disposed almost immediately after creation, and
/// any subsequent use of `ref` inside `onDispose` (or anything scheduled
/// after disposal, like the debounce Timer) throws:
///   "Cannot use the Ref of videoProgressProvider(...) after it has been disposed."
///
/// All external dependencies (`SyncLessonProgress`, `VideoPlayerRepository`)
/// are resolved once during [build] and cached as fields. `_syncToDb` and
/// `_logCompletion` must NEVER call `ref.read`/`ref.watch` themselves,
/// since they can run from `onDispose` or from a Timer that fires after
/// disposal — at which point `ref` is no longer usable.

abstract class _$VideoProgress extends $Notifier<VideoState> {
  late final _$args = ref.$arg as (String, String);
  String get courseId => _$args.$1;
  String get lessonId => _$args.$2;

  VideoState build(String courseId, String lessonId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<VideoState, VideoState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<VideoState, VideoState>,
              VideoState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
