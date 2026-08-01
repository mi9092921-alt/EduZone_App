import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/arb/app_localizations.dart';
import 'permission_item.dart';

Future<List<PermissionItem>> buildPermissionItems({
  required AppLocalizations l10n,
}) async {
  final mediaPermission = await _resolveMediaPermission();

  return [
    PermissionItem(
      kind: AppPermissionKind.location,
      permission: Permission.locationWhenInUse,
      label: l10n.locationPermission,
     // description: l10n.locationPermissionDescription,
    ),
    PermissionItem(
      kind: AppPermissionKind.camera,
      permission: Permission.camera,
      label: l10n.cameraPermission,
     // description: l10n.cameraPermissionDescription,
    ),
    PermissionItem(
      kind: AppPermissionKind.media,
      permission: mediaPermission,
      label: l10n.mediaPermission,
     // description: l10n.mediaPermissionDescription,
    ),
    PermissionItem(
      kind: AppPermissionKind.notifications,
      permission: Permission.notification,
      label: l10n.notificationPermission,
     // description: l10n.notificationPermissionDescription,
    ),
  ];
}

Future<Permission> _resolveMediaPermission() async {
  if (Platform.isIOS) {
    return Permission.photos;
  }

  final info = await DeviceInfoPlugin().androidInfo;
  if (info.version.sdkInt >= 33) {
    return Permission.photos;
  }

  return Permission.storage;
}
