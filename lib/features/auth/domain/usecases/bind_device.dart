import '../entities/bind_device_result.dart';
import '../repositories/auth_repository.dart';

/// Calls `bind_device_for_current_user()` RPC to register the current device.
class BindDevice {
  final AuthRepository repository;

  BindDevice(this.repository);

  Future<BindDeviceResult> call(
    String deviceId,
    Map<String, dynamic> deviceInfo,
    String platform,
  ) {
    return repository.bindDevice(deviceId, deviceInfo, platform);
  }
}
