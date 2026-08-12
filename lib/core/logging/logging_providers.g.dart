// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'logging_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(eventBus)
final eventBusProvider = EventBusProvider._();

final class EventBusProvider
    extends $FunctionalProvider<EventBus, EventBus, EventBus>
    with $Provider<EventBus> {
  EventBusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'eventBusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$eventBusHash();

  @$internal
  @override
  $ProviderElement<EventBus> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EventBus create(Ref ref) {
    return eventBus(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EventBus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EventBus>(value),
    );
  }
}

String _$eventBusHash() => r'8ba44d1ef7b3d3e90ece60350b2693dae64a6b89';

@ProviderFor(logQueue)
final logQueueProvider = LogQueueProvider._();

final class LogQueueProvider
    extends $FunctionalProvider<LogQueue, LogQueue, LogQueue>
    with $Provider<LogQueue> {
  LogQueueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'logQueueProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$logQueueHash();

  @$internal
  @override
  $ProviderElement<LogQueue> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LogQueue create(Ref ref) {
    return logQueue(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LogQueue value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LogQueue>(value),
    );
  }
}

String _$logQueueHash() => r'f2ffcb97d4cfbaf212b69fa617f9cf86f841caca';

@ProviderFor(logRemoteDataSource)
final logRemoteDataSourceProvider = LogRemoteDataSourceProvider._();

final class LogRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          LogRemoteDataSource,
          LogRemoteDataSource,
          LogRemoteDataSource
        >
    with $Provider<LogRemoteDataSource> {
  LogRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'logRemoteDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$logRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<LogRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LogRemoteDataSource create(Ref ref) {
    return logRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LogRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LogRemoteDataSource>(value),
    );
  }
}

String _$logRemoteDataSourceHash() =>
    r'2d1b40527d9727cfd10994fa7e646fc9b7bc7633';

@ProviderFor(logEncryptionService)
final logEncryptionServiceProvider = LogEncryptionServiceProvider._();

final class LogEncryptionServiceProvider
    extends
        $FunctionalProvider<
          LogEncryptionService,
          LogEncryptionService,
          LogEncryptionService
        >
    with $Provider<LogEncryptionService> {
  LogEncryptionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'logEncryptionServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$logEncryptionServiceHash();

  @$internal
  @override
  $ProviderElement<LogEncryptionService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LogEncryptionService create(Ref ref) {
    return logEncryptionService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LogEncryptionService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LogEncryptionService>(value),
    );
  }
}

String _$logEncryptionServiceHash() =>
    r'7d21ddf566de16325dfaab03813c2acafa6d469f';

@ProviderFor(syncEngine)
final syncEngineProvider = SyncEngineProvider._();

final class SyncEngineProvider
    extends $FunctionalProvider<SyncEngine, SyncEngine, SyncEngine>
    with $Provider<SyncEngine> {
  SyncEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncEngineHash();

  @$internal
  @override
  $ProviderElement<SyncEngine> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncEngine create(Ref ref) {
    return syncEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncEngine>(value),
    );
  }
}

String _$syncEngineHash() => r'663fce3592f9cbec121e03e4c3ba4b0d5801a811';

@ProviderFor(eventDispatcher)
final eventDispatcherProvider = EventDispatcherProvider._();

final class EventDispatcherProvider
    extends
        $FunctionalProvider<EventDispatcher, EventDispatcher, EventDispatcher>
    with $Provider<EventDispatcher> {
  EventDispatcherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'eventDispatcherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$eventDispatcherHash();

  @$internal
  @override
  $ProviderElement<EventDispatcher> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EventDispatcher create(Ref ref) {
    return eventDispatcher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EventDispatcher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EventDispatcher>(value),
    );
  }
}

String _$eventDispatcherHash() => r'ab660f3373633b681989ce12d0bd946ee70877c6';
