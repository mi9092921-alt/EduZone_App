// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(deviceService)
final deviceServiceProvider = DeviceServiceProvider._();

final class DeviceServiceProvider
    extends $FunctionalProvider<DeviceService, DeviceService, DeviceService>
    with $Provider<DeviceService> {
  DeviceServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceServiceHash();

  @$internal
  @override
  $ProviderElement<DeviceService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DeviceService create(Ref ref) {
    return deviceService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceService>(value),
    );
  }
}

String _$deviceServiceHash() => r'8de92d6e00039962df2e1dd43a561b5584bb34fd';
