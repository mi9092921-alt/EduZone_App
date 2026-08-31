// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_di_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(supabaseClient)
final supabaseClientProvider = SupabaseClientProvider._();

final class SupabaseClientProvider
    extends $FunctionalProvider<SupabaseClient, SupabaseClient, SupabaseClient>
    with $Provider<SupabaseClient> {
  SupabaseClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supabaseClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supabaseClientHash();

  @$internal
  @override
  $ProviderElement<SupabaseClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SupabaseClient create(Ref ref) {
    return supabaseClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SupabaseClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SupabaseClient>(value),
    );
  }
}

String _$supabaseClientHash() => r'41562033a9661979c5a73a019fae2e48cc53fd47';

@ProviderFor(authRemoteDataSource)
final authRemoteDataSourceProvider = AuthRemoteDataSourceProvider._();

final class AuthRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          AuthRemoteDataSource,
          AuthRemoteDataSource,
          AuthRemoteDataSource
        >
    with $Provider<AuthRemoteDataSource> {
  AuthRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authRemoteDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<AuthRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AuthRemoteDataSource create(Ref ref) {
    return authRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRemoteDataSource>(value),
    );
  }
}

String _$authRemoteDataSourceHash() =>
    r'9913d41192aa8525aa5615455a5d02e74cc65336';

@ProviderFor(authRepository)
final authRepositoryProvider = AuthRepositoryProvider._();

final class AuthRepositoryProvider
    extends $FunctionalProvider<AuthRepository, AuthRepository, AuthRepository>
    with $Provider<AuthRepository> {
  AuthRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authRepositoryHash();

  @$internal
  @override
  $ProviderElement<AuthRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthRepository create(Ref ref) {
    return authRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRepository>(value),
    );
  }
}

String _$authRepositoryHash() => r'360ac8b7d19c65768e5bb5d875d7db55d010c8e5';

@ProviderFor(loginUserUseCase)
final loginUserUseCaseProvider = LoginUserUseCaseProvider._();

final class LoginUserUseCaseProvider
    extends $FunctionalProvider<LoginUser, LoginUser, LoginUser>
    with $Provider<LoginUser> {
  LoginUserUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loginUserUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loginUserUseCaseHash();

  @$internal
  @override
  $ProviderElement<LoginUser> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LoginUser create(Ref ref) {
    return loginUserUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LoginUser value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LoginUser>(value),
    );
  }
}

String _$loginUserUseCaseHash() => r'c33a90ab71d854e711e52fa9990225e4b1ca5550';

@ProviderFor(checkStudentAppAccessUseCase)
final checkStudentAppAccessUseCaseProvider =
    CheckStudentAppAccessUseCaseProvider._();

final class CheckStudentAppAccessUseCaseProvider
    extends
        $FunctionalProvider<
          CheckStudentAppAccess,
          CheckStudentAppAccess,
          CheckStudentAppAccess
        >
    with $Provider<CheckStudentAppAccess> {
  CheckStudentAppAccessUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'checkStudentAppAccessUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$checkStudentAppAccessUseCaseHash();

  @$internal
  @override
  $ProviderElement<CheckStudentAppAccess> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CheckStudentAppAccess create(Ref ref) {
    return checkStudentAppAccessUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CheckStudentAppAccess value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CheckStudentAppAccess>(value),
    );
  }
}

// NOTE: this hash is a placeholder carried over from the old
// _$checkUserAccessUseCaseHash — regenerate via `dart run build_runner
// build` so Riverpod's source hash matches the renamed function again.
String _$checkStudentAppAccessUseCaseHash() =>
    r'81ebf7e8657a3983b588f1c22392066a73f58a8b';

@ProviderFor(bindDeviceUseCase)
final bindDeviceUseCaseProvider = BindDeviceUseCaseProvider._();

final class BindDeviceUseCaseProvider
    extends $FunctionalProvider<BindDevice, BindDevice, BindDevice>
    with $Provider<BindDevice> {
  BindDeviceUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bindDeviceUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bindDeviceUseCaseHash();

  @$internal
  @override
  $ProviderElement<BindDevice> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BindDevice create(Ref ref) {
    return bindDeviceUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BindDevice value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BindDevice>(value),
    );
  }
}

String _$bindDeviceUseCaseHash() => r'34e7a857b99f570df24d7e490c7f5b4ea91dd369';

@ProviderFor(logoutUserUseCase)
final logoutUserUseCaseProvider = LogoutUserUseCaseProvider._();

final class LogoutUserUseCaseProvider
    extends $FunctionalProvider<LogoutUser, LogoutUser, LogoutUser>
    with $Provider<LogoutUser> {
  LogoutUserUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'logoutUserUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$logoutUserUseCaseHash();

  @$internal
  @override
  $ProviderElement<LogoutUser> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LogoutUser create(Ref ref) {
    return logoutUserUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LogoutUser value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LogoutUser>(value),
    );
  }
}

String _$logoutUserUseCaseHash() => r'fc579b58d99c7272b069fd93c2c611188dcc1836';

@ProviderFor(validateDeviceExistsUseCase)
final validateDeviceExistsUseCaseProvider =
    ValidateDeviceExistsUseCaseProvider._();

final class ValidateDeviceExistsUseCaseProvider
    extends
        $FunctionalProvider<
          ValidateDeviceExists,
          ValidateDeviceExists,
          ValidateDeviceExists
        >
    with $Provider<ValidateDeviceExists> {
  ValidateDeviceExistsUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'validateDeviceExistsUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$validateDeviceExistsUseCaseHash();

  @$internal
  @override
  $ProviderElement<ValidateDeviceExists> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ValidateDeviceExists create(Ref ref) {
    return validateDeviceExistsUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ValidateDeviceExists value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ValidateDeviceExists>(value),
    );
  }
}

String _$validateDeviceExistsUseCaseHash() =>
    r'956811422ec308096299901f9b20341ce60f5f39';

@ProviderFor(getCurrentUserUseCase)
final getCurrentUserUseCaseProvider = GetCurrentUserUseCaseProvider._();

final class GetCurrentUserUseCaseProvider
    extends $FunctionalProvider<GetCurrentUser, GetCurrentUser, GetCurrentUser>
    with $Provider<GetCurrentUser> {
  GetCurrentUserUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getCurrentUserUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getCurrentUserUseCaseHash();

  @$internal
  @override
  $ProviderElement<GetCurrentUser> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GetCurrentUser create(Ref ref) {
    return getCurrentUserUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetCurrentUser value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetCurrentUser>(value),
    );
  }
}

String _$getCurrentUserUseCaseHash() =>
    r'bd69cafdf35de78799e5483eb5dab553f2c249ca';

@ProviderFor(updateRemoteDataSource)
final updateRemoteDataSourceProvider = UpdateRemoteDataSourceProvider._();

final class UpdateRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          UpdateRemoteDataSource,
          UpdateRemoteDataSource,
          UpdateRemoteDataSource
        >
    with $Provider<UpdateRemoteDataSource> {
  UpdateRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateRemoteDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<UpdateRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UpdateRemoteDataSource create(Ref ref) {
    return updateRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateRemoteDataSource>(value),
    );
  }
}

String _$updateRemoteDataSourceHash() =>
    r'0910f13b7399e7bd905caf427b867e08b99345d0';

@ProviderFor(updateService)
final updateServiceProvider = UpdateServiceProvider._();

final class UpdateServiceProvider
    extends $FunctionalProvider<UpdateService, UpdateService, UpdateService>
    with $Provider<UpdateService> {
  UpdateServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateServiceHash();

  @$internal
  @override
  $ProviderElement<UpdateService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UpdateService create(Ref ref) {
    return updateService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateService>(value),
    );
  }
}

String _$updateServiceHash() => r'3546ad8a4dda29fdad06a70f36d618fd119591c6';

/// Wraps the background device/activity/session sync that used to be a
/// private method on the `Auth` notifier. See [AuthActivitySyncService]
/// for the extraction rationale.

@ProviderFor(authActivitySyncService)
final authActivitySyncServiceProvider = AuthActivitySyncServiceProvider._();

/// Wraps the background device/activity/session sync that used to be a
/// private method on the `Auth` notifier. See [AuthActivitySyncService]
/// for the extraction rationale.

final class AuthActivitySyncServiceProvider
    extends
        $FunctionalProvider<
          AuthActivitySyncService,
          AuthActivitySyncService,
          AuthActivitySyncService
        >
    with $Provider<AuthActivitySyncService> {
  /// Wraps the background device/activity/session sync that used to be a
  /// private method on the `Auth` notifier. See [AuthActivitySyncService]
  /// for the extraction rationale.
  AuthActivitySyncServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authActivitySyncServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authActivitySyncServiceHash();

  @$internal
  @override
  $ProviderElement<AuthActivitySyncService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AuthActivitySyncService create(Ref ref) {
    return authActivitySyncService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthActivitySyncService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthActivitySyncService>(value),
    );
  }
}

String _$authActivitySyncServiceHash() =>
    r'7bc1de088d7d272ab28abf25131e97593333ead7';
