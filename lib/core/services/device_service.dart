import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../utils/device_info_helper.dart';

part 'device_service.g.dart';

abstract class DeviceService {
  String get fingerprint;
  bool get isEmulator;
  Map<String, dynamic> get deviceInfoJson;
  String get platform;
}

class HardwareDeviceService implements DeviceService {
  @override
  String get fingerprint => DeviceInfoHelper.fingerprint;

  @override
  bool get isEmulator => DeviceInfoHelper.isEmulator;

  @override
  Map<String, dynamic> get deviceInfoJson => DeviceInfoHelper.deviceInfoJson;

  @override
  String get platform => DeviceInfoHelper.platform;
}

@riverpod
DeviceService deviceService(Ref ref) {
  return HardwareDeviceService();
}
