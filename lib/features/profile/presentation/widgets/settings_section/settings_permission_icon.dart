import 'package:flutter/material.dart';

import '../../../../../core/permissions/permission_item.dart';
import '../../../../../design_system/design_system.dart';

/// Icon shown next to a permission row in the permissions card.
///
/// Pure function — didn't depend on any widget state in the original
/// `_iconForPermission`, so it moves out unchanged and is now directly
/// unit-testable.
IconData iconForPermission(AppPermissionKind kind) {
  switch (kind) {
    case AppPermissionKind.location:
      return Icons.location_on_rounded;
    case AppPermissionKind.camera:
      return Icons.camera_alt_rounded;
    case AppPermissionKind.media:
      return Icons.photo_library_rounded;
    case AppPermissionKind.notifications:
      return AppIcons.notification;
  }
}
