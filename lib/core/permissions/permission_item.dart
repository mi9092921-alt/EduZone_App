import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

enum AppPermissionKind { location, camera, media, notifications }

@immutable
class PermissionItem {
  const PermissionItem({
    required this.kind,
    required this.permission,
    required this.label,
    // required this.description,
  });

  final AppPermissionKind kind;
  final Permission permission;
  final String label;
  // final String description;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PermissionItem &&
            runtimeType == other.runtimeType &&
            kind == other.kind;
  }

  @override
  int get hashCode => kind.hashCode;
}
