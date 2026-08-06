import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../core/network/supabase_client.dart';
import '../../../../core/services/device_service.dart';
import '../../application/services/auth_activity_sync_service.dart';
import '../../application/services/update_service.dart';
import '../../data/datasources/auth_remote_ds.dart';
import '../../data/datasources/update_remote_ds.dart';
import '../../data/repositories/auth_repo_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/bind_device.dart';
import '../../domain/usecases/check_user_access.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/login_user.dart';
import '../../domain/usecases/logout_user.dart';
import '../../domain/usecases/validate_device_exists.dart';

part 'auth_di_providers.g.dart';

// ─── Dependency-injection wiring for the auth feature ───────────────────────
//
// Split out of auth_provider.dart (which now holds only the `Auth`
// notifier itself) purely to keep that file focused on the stateful
// session-management logic. These are plain, side-effect-free provider
// declarations — none of them contain business logic, so grouping them
// here keeps auth_provider.dart's diff/review surface small whenever a
// new use case is wired in.
//
// Overriding authRemoteDataSourceProvider in tests (as
// auth_notifier_test.dart already does) transparently flows through to
// authRepositoryProvider and every use case below — no test changes
// required by this split.

@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(Ref ref) => SupabaseService.client;

@Riverpod(keepAlive: true)
AuthRemoteDataSource authRemoteDataSource(Ref ref) => AuthRemoteDataSource();

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) =>
    AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider));

@Riverpod(keepAlive: true)
LoginUser loginUserUseCase(Ref ref) =>
    LoginUser(ref.watch(authRepositoryProvider));

@Riverpod(keepAlive: true)
CheckUserAccess checkUserAccessUseCase(Ref ref) =>
    CheckUserAccess(ref.watch(authRepositoryProvider));

@Riverpod(keepAlive: true)
BindDevice bindDeviceUseCase(Ref ref) =>
    BindDevice(ref.watch(authRepositoryProvider));

// Intentionally unused in production — see doc comment on LogoutUser for why
// Auth.logout() uses LogoutOrchestrator instead. Kept as a documented,
// tested fallback.
@Riverpod(keepAlive: true)
LogoutUser logoutUserUseCase(Ref ref) =>
    LogoutUser(ref.watch(authRepositoryProvider));

@Riverpod(keepAlive: true)
ValidateDeviceExists validateDeviceExistsUseCase(Ref ref) =>
    ValidateDeviceExists(ref.watch(authRepositoryProvider));

@Riverpod(keepAlive: true)
GetCurrentUser getCurrentUserUseCase(Ref ref) =>
    GetCurrentUser(ref.watch(authRepositoryProvider));

@Riverpod(keepAlive: true)
UpdateRemoteDataSource updateRemoteDataSource(Ref ref) =>
    UpdateRemoteDataSource();

@Riverpod(keepAlive: true)
UpdateService updateService(Ref ref) =>
    UpdateService(ref.watch(updateRemoteDataSourceProvider));

/// Wraps the background device/activity/session sync that used to be a
/// private method on the `Auth` notifier. See [AuthActivitySyncService]
/// for the extraction rationale.
@Riverpod(keepAlive: true)
AuthActivitySyncService authActivitySyncService(Ref ref) =>
    AuthActivitySyncService(
      remoteDataSource: ref.watch(authRemoteDataSourceProvider),
      deviceService: ref.watch(deviceServiceProvider),
      bindDevice: ref.watch(bindDeviceUseCaseProvider),
    );
