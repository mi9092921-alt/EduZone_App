@Tags(['golden'])
library;

import 'package:app/design_system/tokens/app_colors.dart';
import 'package:app/features/profile/presentation/widgets/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrapWithTheme(Widget child) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        extensions: [DesignSystemColors.light()],
      ),
      home: Scaffold(body: child),
    );
  }

  group('SettingsTile Goldens', () {
    testWidgets('Basic SettingsTile', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 100));

      await tester.pumpWidget(
        wrapWithTheme(
          SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            onTap: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();
      await expectLater(
        find.byType(SettingsTile),
        matchesGoldenFile('goldens/settings_tile_basic.png'),
      );
    });

    testWidgets('SettingsTile with Subtitle and Trailing', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 120));

      await tester.pumpWidget(
        wrapWithTheme(
          SettingsTile(
            icon: Icons.language_rounded,
            title: 'Language',
            subtitle: 'Arabic',
            trailing: const Text(
              'العربية',
              style: TextStyle(color: Colors.blue),
            ),
            onTap: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();
      await expectLater(
        find.byType(SettingsTile),
        matchesGoldenFile('goldens/settings_tile_full.png'),
      );
    });
  });
}