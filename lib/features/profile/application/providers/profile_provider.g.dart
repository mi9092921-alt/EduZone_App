// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(profileRepository)
final profileRepositoryProvider = ProfileRepositoryProvider._();

final class ProfileRepositoryProvider
    extends
        $FunctionalProvider<
          ProfileRepository,
          ProfileRepository,
          ProfileRepository
        >
    with $Provider<ProfileRepository> {
  ProfileRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProfileRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProfileRepository create(Ref ref) {
    return profileRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileRepository>(value),
    );
  }
}

String _$profileRepositoryHash() => r'0aee9106bd4697126db6c675e1cf5d9ceba9b438';

@ProviderFor(getProfileUseCase)
final getProfileUseCaseProvider = GetProfileUseCaseProvider._();

final class GetProfileUseCaseProvider
    extends $FunctionalProvider<GetProfile, GetProfile, GetProfile>
    with $Provider<GetProfile> {
  GetProfileUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getProfileUseCaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getProfileUseCaseHash();

  @$internal
  @override
  $ProviderElement<GetProfile> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GetProfile create(Ref ref) {
    return getProfileUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetProfile value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetProfile>(value),
    );
  }
}

String _$getProfileUseCaseHash() => r'f13e676c48260ff72d2a1ba86409a4f4393b8093';

@ProviderFor(updateProfileUseCase)
final updateProfileUseCaseProvider = UpdateProfileUseCaseProvider._();

final class UpdateProfileUseCaseProvider
    extends $FunctionalProvider<UpdateProfile, UpdateProfile, UpdateProfile>
    with $Provider<UpdateProfile> {
  UpdateProfileUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateProfileUseCaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateProfileUseCaseHash();

  @$internal
  @override
  $ProviderElement<UpdateProfile> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UpdateProfile create(Ref ref) {
    return updateProfileUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateProfile value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateProfile>(value),
    );
  }
}

String _$updateProfileUseCaseHash() =>
    r'726d4f2327f73d9a6a7a40ec2cc7ca44fbaef6b5';

@ProviderFor(profile)
final profileProvider = ProfileProvider._();

final class ProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<StudentProfile>,
          StudentProfile,
          FutureOr<StudentProfile>
        >
    with $FutureModifier<StudentProfile>, $FutureProvider<StudentProfile> {
  ProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileHash();

  @$internal
  @override
  $FutureProviderElement<StudentProfile> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<StudentProfile> create(Ref ref) {
    return profile(ref);
  }
}

String _$profileHash() => r'7fac7a318e770cca36629d2fa0ba4c1a7ed2cf96';

@ProviderFor(ProfileActions)
final profileActionsProvider = ProfileActionsProvider._();

final class ProfileActionsProvider
    extends $NotifierProvider<ProfileActions, ProfileActionsState> {
  ProfileActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileActionsHash();

  @$internal
  @override
  ProfileActions create() => ProfileActions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileActionsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileActionsState>(value),
    );
  }
}

String _$profileActionsHash() => r'bd049c61135b2800e330889f8143b8a13958b6e2';

abstract class _$ProfileActions extends $Notifier<ProfileActionsState> {
  ProfileActionsState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ProfileActionsState, ProfileActionsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ProfileActionsState, ProfileActionsState>,
              ProfileActionsState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
