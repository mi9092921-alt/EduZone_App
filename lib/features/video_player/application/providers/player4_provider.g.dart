// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player4_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(player4RemoteDataSource)
final player4RemoteDataSourceProvider = Player4RemoteDataSourceProvider._();

final class Player4RemoteDataSourceProvider
    extends
        $FunctionalProvider<
          Player4RemoteDataSource,
          Player4RemoteDataSource,
          Player4RemoteDataSource
        >
    with $Provider<Player4RemoteDataSource> {
  Player4RemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'player4RemoteDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$player4RemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<Player4RemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Player4RemoteDataSource create(Ref ref) {
    return player4RemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Player4RemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Player4RemoteDataSource>(value),
    );
  }
}

String _$player4RemoteDataSourceHash() =>
    r'68dbc7bc0103de8490f93136c603e1a72a36d004';

@ProviderFor(Player4VideoInfo)
final player4VideoInfoProvider = Player4VideoInfoFamily._();

final class Player4VideoInfoProvider
    extends $AsyncNotifierProvider<Player4VideoInfo, StreamingVideoInfo> {
  Player4VideoInfoProvider._({
    required Player4VideoInfoFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'player4VideoInfoProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$player4VideoInfoHash();

  @override
  String toString() {
    return r'player4VideoInfoProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  Player4VideoInfo create() => Player4VideoInfo();

  @override
  bool operator ==(Object other) {
    return other is Player4VideoInfoProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$player4VideoInfoHash() => r'ecbd71928ad0ae6c953fabef6f47f2c5541b7007';

final class Player4VideoInfoFamily extends $Family
    with
        $ClassFamilyOverride<
          Player4VideoInfo,
          AsyncValue<StreamingVideoInfo>,
          StreamingVideoInfo,
          FutureOr<StreamingVideoInfo>,
          String
        > {
  Player4VideoInfoFamily._()
    : super(
        retry: null,
        name: r'player4VideoInfoProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  Player4VideoInfoProvider call(String videoId) =>
      Player4VideoInfoProvider._(argument: videoId, from: this);

  @override
  String toString() => r'player4VideoInfoProvider';
}

abstract class _$Player4VideoInfo extends $AsyncNotifier<StreamingVideoInfo> {
  late final _$args = ref.$arg as String;
  String get videoId => _$args;

  FutureOr<StreamingVideoInfo> build(String videoId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<StreamingVideoInfo>, StreamingVideoInfo>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<StreamingVideoInfo>, StreamingVideoInfo>,
              AsyncValue<StreamingVideoInfo>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
