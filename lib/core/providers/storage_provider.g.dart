// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Core-level provider for the [StorageService] singleton.
///
/// Kept alive so the SQLite connection persists across the app lifecycle.
/// Previously defined inside the downloads feature; moved here so that
/// multiple features (downloads, bookmarks) can depend on it without
/// cross-feature imports.

@ProviderFor(storageService)
final storageServiceProvider = StorageServiceProvider._();

/// Core-level provider for the [StorageService] singleton.
///
/// Kept alive so the SQLite connection persists across the app lifecycle.
/// Previously defined inside the downloads feature; moved here so that
/// multiple features (downloads, bookmarks) can depend on it without
/// cross-feature imports.

final class StorageServiceProvider
    extends $FunctionalProvider<StorageService, StorageService, StorageService>
    with $Provider<StorageService> {
  /// Core-level provider for the [StorageService] singleton.
  ///
  /// Kept alive so the SQLite connection persists across the app lifecycle.
  /// Previously defined inside the downloads feature; moved here so that
  /// multiple features (downloads, bookmarks) can depend on it without
  /// cross-feature imports.
  StorageServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'storageServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$storageServiceHash();

  @$internal
  @override
  $ProviderElement<StorageService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StorageService create(Ref ref) {
    return storageService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StorageService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StorageService>(value),
    );
  }
}

String _$storageServiceHash() => r'62cbe9319bc400f2f78b16bce45d667585b592a2';
