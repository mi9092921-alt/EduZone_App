import 'package:app/core/permissions/permission_item.dart';
import 'package:app/features/profile/presentation/widgets/settings_section/settings_permissions_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

import 'settings_section_test_helpers.dart';

void main() {
  group('SettingsPermissionsCard', () {
    testWidgets('shows a skeleton when loading with no items yet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          SettingsPermissionsCard(
            isLoading: true,
            items: const [],
            statuses: const {},
            onRequestPermission: (_) {},
          ),
        ),
      );

      // The skeleton renders 3 placeholder tiles.
      expect(find.text('Permission'), findsNWidgets(3));
    });

    testWidgets('renders each permission item with its status label', (
      WidgetTester tester,
    ) async {
      const items = [
        PermissionItem(
          kind: AppPermissionKind.camera,
          permission: Permission.camera,
          label: 'Camera',
        ),
        PermissionItem(
          kind: AppPermissionKind.location,
          permission: Permission.location,
          label: 'Location',
        ),
      ];

      await tester.pumpWidget(
        buildTestableWidget(
          SettingsPermissionsCard(
            isLoading: false,
            items: items,
            statuses: const {AppPermissionKind.camera: PermissionStatus.granted},
            onRequestPermission: (_) {},
          ),
        ),
      );

      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
    });

    testWidgets('tapping a permission row fires onRequestPermission with that item', (
      WidgetTester tester,
    ) async {
      const item = PermissionItem(
        kind: AppPermissionKind.camera,
        permission: Permission.camera,
        label: 'Camera',
      );

      PermissionItem? requested;

      await tester.pumpWidget(
        buildTestableWidget(
          SettingsPermissionsCard(
            isLoading: false,
            items: const [item],
            statuses: const {},
            onRequestPermission: (i) => requested = i,
          ),
        ),
      );

      await tester.tap(find.text('Camera'));
      await tester.pump();

      expect(requested, item);
    });

    testWidgets('keeps every row inert while isRequesting is true', (
      WidgetTester tester,
    ) async {
      const cameraItem = PermissionItem(
        kind: AppPermissionKind.camera,
        permission: Permission.camera,
        label: 'Camera',
      );

      var requested = 0;

      await tester.pumpWidget(
        buildTestableWidget(
          SettingsPermissionsCard(
            isLoading: false,
            items: const [cameraItem],
            statuses: const {},
            onRequestPermission: (_) => requested++,
            isRequesting: true,
          ),
        ),
      );

      // Simulates a second tap racing the still-pending native dialog —
      // this is the tap that used to hit permission_handler's "a request
      // for permissions is already running" PlatformException (Sentry
      // EDUZONE-W). With isRequesting the row must not fire.
      await tester.tap(find.text('Camera'), warnIfMissed: false);
      await tester.pump();

      expect(requested, 0);
    });
  });
}
