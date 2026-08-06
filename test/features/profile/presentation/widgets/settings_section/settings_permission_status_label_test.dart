import 'package:app/features/profile/presentation/widgets/settings_section/settings_permission_status_label.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

import 'settings_section_test_helpers.dart';

void main() {
  group('permissionStatusLabel', () {
    testWidgets('returns the granted label for PermissionStatus.granted', (
      WidgetTester tester,
    ) async {
      await withLocalizations(tester, (l10n) {
        expect(
          permissionStatusLabel(PermissionStatus.granted, l10n),
          l10n.permissionGranted,
        );
      });
    });

    testWidgets(
      'returns the permanently-denied label for PermissionStatus.permanentlyDenied',
      (WidgetTester tester) async {
        await withLocalizations(tester, (l10n) {
          expect(
            permissionStatusLabel(PermissionStatus.permanentlyDenied, l10n),
            l10n.permissionPermanentlyDenied,
          );
        });
      },
    );

    testWidgets('returns the denied label for PermissionStatus.denied', (
      WidgetTester tester,
    ) async {
      await withLocalizations(tester, (l10n) {
        expect(
          permissionStatusLabel(PermissionStatus.denied, l10n),
          l10n.permissionDenied,
        );
      });
    });

    testWidgets('treats a null status the same as denied', (
      WidgetTester tester,
    ) async {
      await withLocalizations(tester, (l10n) {
        expect(permissionStatusLabel(null, l10n), l10n.permissionDenied);
      });
    });
  });
}
