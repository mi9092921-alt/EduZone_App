import 'package:app/design_system/tokens/app_colors.dart';
import 'package:app/design_system/tokens/app_elevation.dart';
import 'package:app/design_system/tokens/app_theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CourseCardTheme factories', () {
    test('light() uses the light surface/border palette', () {
      final theme = CourseCardTheme.light();
      expect(theme.backgroundColor, AppColors.lightSurface);
      expect(theme.borderColor, AppColors.lightBorder);
      expect(theme.elevation, AppElevation.sm);
    });

    test('dark() uses the dark surface/border palette', () {
      final theme = CourseCardTheme.dark();
      expect(theme.backgroundColor, AppColors.darkSurface);
      expect(theme.borderColor, AppColors.darkBorder);
      expect(theme.elevation, AppElevation.md);
    });

    test('copyWith overrides only the given fields', () {
      final base = CourseCardTheme.light();
      final tinted = base.copyWith(elevation: 99);

      expect(tinted.elevation, 99);
      expect(tinted.backgroundColor, base.backgroundColor);
      expect(tinted.borderColor, base.borderColor);
    });

    test('lerp at t=0 and t=1 returns the boundary elevations', () {
      final light = CourseCardTheme.light();
      final dark = CourseCardTheme.dark();

      expect(light.lerp(dark, 0).elevation, light.elevation);
      expect(light.lerp(dark, 1).elevation, dark.elevation);
    });

    test('lerp returns `this` unchanged for an incompatible extension', () {
      final light = CourseCardTheme.light();
      expect(light.lerp(null, 0.5), same(light));
    });
  });

  group('AppThemeX.courseCardTheme', () {
    testWidgets('resolves the CourseCardTheme registered on the ambient '
        'Theme', (tester) async {
      late CourseCardTheme resolved;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [CourseCardTheme.dark()]),
          home: Builder(
            builder: (context) {
              resolved = context.courseCardTheme;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved.backgroundColor, AppColors.darkSurface);
    });
  });
}
