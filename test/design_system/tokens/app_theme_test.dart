import 'package:app/design_system/tokens/app_colors.dart';
import 'package:app/design_system/tokens/app_theme.dart';
import 'package:app/design_system/tokens/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const locale = Locale('en');

  group('AppTheme.light', () {
    late ThemeData theme;

    setUp(() {
      theme = AppTheme.light(locale);
    });

    test('enables Material 3', () {
      expect(theme.useMaterial3, isTrue);
    });

    test('color scheme is light brightness with the brand primary', () {
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.surface, AppColors.lightSurface);
    });

    test('registers both DesignSystemColors.light and CourseCardTheme.light',
        () {
      final colors = theme.extension<DesignSystemColors>();
      final cardTheme = theme.extension<CourseCardTheme>();

      expect(colors, isNotNull);
      expect(colors!.background, AppColors.lightBackground);
      expect(cardTheme, isNotNull);
      expect(cardTheme!.backgroundColor, AppColors.lightSurface);
    });

    test('navigation bar uses always-show labels at the standard height', () {
      expect(theme.navigationBarTheme.labelBehavior,
          NavigationDestinationLabelBehavior.alwaysShow);
      expect(theme.navigationBarTheme.height, 72);
    });

    test('scaffold background follows the lowest surface container', () {
      expect(
        theme.scaffoldBackgroundColor,
        theme.colorScheme.surfaceContainerLowest,
      );
    });
  });

  group('AppTheme.dark', () {
    late ThemeData theme;

    setUp(() {
      theme = AppTheme.dark(locale);
    });

    test('color scheme is dark brightness with the brand primary', () {
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.surface, AppColors.darkSurface);
    });

    test('registers both DesignSystemColors.dark and CourseCardTheme.dark',
        () {
      final colors = theme.extension<DesignSystemColors>();
      final cardTheme = theme.extension<CourseCardTheme>();

      expect(colors, isNotNull);
      expect(colors!.background, AppColors.darkBackground);
      expect(cardTheme, isNotNull);
      expect(cardTheme!.backgroundColor, AppColors.darkSurface);
    });
  });

  test('light and dark themes share the same brand primary color', () {
    final light = AppTheme.light(locale);
    final dark = AppTheme.dark(locale);
    expect(light.colorScheme.primary, dark.colorScheme.primary);
  });

  testWidgets(
    'building either theme does not throw for the Arabic locale',
    (tester) async {
      // Plain test()/expect(returnsNormally) isn't enough here: Cairo
      // (triggered by the 'ar' locale) kicks off a fire-and-forget async
      // check against the local asset bundle, which needs a live
      // TestWidgetsFlutterBinding to resolve. testWidgets keeps that
      // binding alive, and pump() flushes the pending future before the
      // test completes instead of letting it fail after the fact.
      expect(() => AppTheme.light(const Locale('ar')), returnsNormally);
      expect(() => AppTheme.dark(const Locale('ar')), returnsNormally);
      await tester.pump();
    },
  );
}
