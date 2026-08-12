// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_cancellation_manager.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Riverpod provider — singleton across the app lifecycle.

@ProviderFor(requestCancellationManager)
final requestCancellationManagerProvider =
    RequestCancellationManagerProvider._();

/// Riverpod provider — singleton across the app lifecycle.

final class RequestCancellationManagerProvider
    extends
        $FunctionalProvider<
          RequestCancellationManager,
          RequestCancellationManager,
          RequestCancellationManager
        >
    with $Provider<RequestCancellationManager> {
  /// Riverpod provider — singleton across the app lifecycle.
  RequestCancellationManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'requestCancellationManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$requestCancellationManagerHash();

  @$internal
  @override
  $ProviderElement<RequestCancellationManager> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RequestCancellationManager create(Ref ref) {
    return requestCancellationManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RequestCancellationManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RequestCancellationManager>(value),
    );
  }
}

String _$requestCancellationManagerHash() =>
    r'61cea1588e757abb00c9c2e66d629939ddc09965';
