import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../permissions/permission_item.dart';

part 'permission_service.g.dart';

abstract class PermissionService {
  Future<ph.PermissionStatus> checkStatus(ph.Permission permission);
  Future<ph.PermissionStatus> request(ph.Permission permission);
  Future<bool> openAppSettings();
  Future<Map<AppPermissionKind, ph.PermissionStatus>> checkAllValues(
    List<PermissionItem> items,
  );
}

class AppPermissionService implements PermissionService {
  @override
  Future<ph.PermissionStatus> checkStatus(ph.Permission permission) async {
    return await permission.status;
  }

  @override
  Future<ph.PermissionStatus> request(ph.Permission permission) async {
    return await permission.request();
  }

  @override
  Future<bool> openAppSettings() async {
    return await ph.openAppSettings();
  }

  @override
  Future<Map<AppPermissionKind, ph.PermissionStatus>> checkAllValues(
    List<PermissionItem> items,
  ) async {
    final statuses = <AppPermissionKind, ph.PermissionStatus>{};
    for (final item in items) {
      statuses[item.kind] = await item.permission.status;
    }
    return statuses;
  }
}

@riverpod
PermissionService permissionService(Ref ref) {
  return AppPermissionService();
}
