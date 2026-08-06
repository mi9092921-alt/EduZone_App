import 'package:app/core/permissions/permission_item.dart';
import 'package:app/design_system/design_system.dart';
import 'package:app/features/profile/presentation/widgets/settings_section/settings_permission_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('iconForPermission', () {
    test('returns the expected icon for every AppPermissionKind', () {
      expect(
        iconForPermission(AppPermissionKind.location),
        Icons.location_on_rounded,
      );
      expect(
        iconForPermission(AppPermissionKind.camera),
        Icons.camera_alt_rounded,
      );
      expect(
        iconForPermission(AppPermissionKind.media),
        Icons.photo_library_rounded,
      );
      expect(
        iconForPermission(AppPermissionKind.notifications),
        AppIcons.notification,
      );
    });
  });
}
