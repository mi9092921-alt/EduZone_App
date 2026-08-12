import 'package:app/design_system/design_system.dart';
import 'package:app/features/profile/presentation/widgets/settings_section/settings_about_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'settings_section_test_helpers.dart';

void main() {
  group('SettingsAboutDialog', () {
    testWidgets('shows the given version string', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const SettingsAboutDialog(version: 'EduZone v1.2.3'),
        ),
      );

      expect(find.text('EduZone v1.2.3'), findsOneWidget);
    });

    testWidgets('showSettingsAboutDialog opens a dialog that can be dismissed via OK', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showSettingsAboutDialog(context, 'v1.0.0'),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('v1.0.0'), findsOneWidget);

      await tester.tap(find.byType(AppButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('v1.0.0'), findsNothing);
    });
  });
}
