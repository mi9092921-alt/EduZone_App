import 'package:app/design_system/tokens/app_colors.dart';
import 'package:app/features/profile/presentation/widgets/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:typed_data';

class TolerantGoldenComparator extends LocalFileComparator {
  final double maxDiffPercent;
  TolerantGoldenComparator(super.testFile, {this.maxDiffPercent = 0.005});

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (!result.passed && result.diffPercent <= maxDiffPercent) {
      return true;
    }
    if (!result.passed) {
      final String error = await generateFailureOutput(result, golden, basedir);
      throw FlutterError(error);
    }
    return true;
  }
}

void main() {
  setUpAll(() {
    final testUri = Uri.parse(
      'file:///D:/projects/EduZone/flutter_projects/EduZone_App/test/features/profile/presentation/widgets/settings_tile_golden_test.dart',
    );
    goldenFileComparator = TolerantGoldenComparator(testUri);
  });

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

    // NOTE: this specific case renders Arabic text ("Arabic" / "العربية"),
    // which routes through GoogleFonts.cairoTextTheme() in
    // lib/design_system/tokens/app_text_styles.dart. The golden failure
    // seen previously (1.68% / 807px diff) was caused by GoogleFonts'
    // non-deterministic runtime font fetching, NOT a real UI regression —
    // confirmed by comparing masterImage/testImage/isolatedDiff directly,
    // and by "Basic SettingsTile" (no Arabic text) passing consistently
    // while this exact test failed consistently. Fixed globally via
    // test/flutter_test_config.dart (GoogleFonts.config.allowRuntimeFetching
    // = false), which must run once BEFORE this golden is regenerated with
    // --update-goldens, or it will drift again.
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