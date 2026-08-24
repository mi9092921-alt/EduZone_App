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
///
/// Passes real secure storage explicitly (rather than relying on a
/// default inside `StorageService`) so the security-critical download
/// metadata this service writes (`security_signature`, P6.22/P6.23) is
/// actually signed in production — `StorageService`'s own constructor
/// deliberately treats a missing secure storage as "skip signing" rather
/// than throwing, exactly so tests and other lightweight instances keep
/// working without a platform channel.

@ProviderFor(storageService)
final storageServiceProvider = StorageServiceProvider._();

/// Core-level provider for the [StorageService] singleton.
///
/// Kept alive so the SQLite connection persists across the app lifecycle.
/// Previously defined inside the downloads feature; moved here so that
/// multiple features (downloads, bookmarks) can depend on it without
/// cross-feature imports.
///
/// Passes real secure storage explicitly (rather than relying on a
/// default inside `StorageService`) so the security-critical download
/// metadata this service writes (`security_signature`, P6.22/P6.23) is
/// actually signed in production — `StorageService`'s own constructor
/// deliberately treats a missing secure storage as "skip signing" rather
/// than throwing, exactly so tests and other lightweight instances keep
/// working without a platform channel.

final class StorageServiceProvider
    extends $FunctionalProvider<StorageService, StorageService, StorageService>
    with $Provider<StorageService> {
  /// Core-level provider for the [StorageService] singleton.
  ///
  /// Kept alive so the SQLite connection persists across the app lifecycle.
  /// Previously defined inside the downloads feature; moved here so that
  /// multiple features (downloads, bookmarks) can depend on it without
  /// cross-feature imports.
  ///
  /// Passes real secure storage explicitly (rather than relying on a
  /// default inside `StorageService`) so the security-critical download
  /// metadata this service writes (`security_signature`, P6.22/P6.23) is
  /// actually signed in production — `StorageService`'s own constructor
  /// deliberately treats a missing secure storage as "skip signing" rather
  /// than throwing, exactly so tests and other lightweight instances keep
  /// working without a platform channel.
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

String _$storageServiceHash() => r'38dd7a117b60a9e81c502d0b845483e3945f8d58';
