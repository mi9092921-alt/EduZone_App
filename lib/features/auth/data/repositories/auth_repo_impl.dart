import '../../domain/entities/app_user.dart';
import '../../domain/entities/bind_device_result.dart';
import '../../domain/entities/user_access.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_ds.dart';

/// Concrete implementation of [AuthRepository].
///
/// Delegates all operations to [AuthRemoteDataSource].
/// Exceptions propagate up as typed [AppException]s — the
/// presentation layer catches and displays localized messages.
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _dataSource;

  AuthRepositoryImpl([AuthRemoteDataSource? dataSource])
    : _dataSource = dataSource ?? AuthRemoteDataSource();

  @override
  Future<UserAccess> checkUserAccess() {
    return _dataSource.checkUserAccess();
  }

  @override
  Future<AppUser> login(String email, String password) {
    return _dataSource.login(email, password);
  }

  @override
  Future<BindDeviceResult> bindDevice(
    String deviceId,
    Map<String, dynamic> deviceInfo,
    String platform,
  ) {
    return _dataSource.bindDevice(deviceId, deviceInfo, platform);
  }

  @override
  Future<void> logout() {
    return _dataSource.logout();
  }

  @override
  Future<bool> validateDeviceExists(String userId, String fingerprint) {
    return _dataSource.validateDeviceExists(userId, fingerprint);
  }

  @override
  Future<AppUser?> getCurrentUser() {
    return _dataSource.getCurrentUser();
  }
}
