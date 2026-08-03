import 'package:app/design_system/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DesignSystemColors factories', () {
    test('light() pulls every field from the light AppColors palette', () {
      final light = DesignSystemColors.light();

      expect(light.background, AppColors.lightBackground);
      expect(light.surface, AppColors.lightSurface);
      expect(light.surface2, AppColors.lightSurface2);
      expect(light.border, AppColors.lightBorder);
      expect(light.textPrimary, AppColors.lightOnSurfacePrimary);
      expect(light.textSecondary, AppColors.lightOnSurfaceSecondary);
      expect(light.textMuted, AppColors.lightOnSurfaceMuted);
      expect(light.primary, AppColors.primary);
      expect(light.primarySoft, AppColors.primarySoft);
    });

    test('dark() pulls every field from the dark AppColors palette', () {
      final dark = DesignSystemColors.dark();

      expect(dark.background, AppColors.darkBackground);
      expect(dark.surface, AppColors.darkSurface);
      expect(dark.surface2, AppColors.darkSurface2);
      expect(dark.border, AppColors.darkBorder);
      expect(dark.textPrimary, AppColors.darkOnSurfacePrimary);
      expect(dark.textSecondary, AppColors.darkOnSurfaceSecondary);
      expect(dark.textMuted, AppColors.darkOnSurfaceMuted);
      // primarySoftDark exists specifically because the light primarySoft
      // is too pale to use as a dark-mode active-state background.
      expect(dark.primarySoft, AppColors.primarySoftDark);
      expect(dark.primarySoft, isNot(AppColors.primarySoft));
    });

    test('light and dark share the same brand primary/success/error', () {
      final light = DesignSystemColors.light();
      final dark = DesignSystemColors.dark();

      expect(light.primary, dark.primary);
      expect(light.success, dark.success);
      expect(light.error, dark.error);
    });

    test('copyWith overrides only the given fields', () {
      final base = DesignSystemColors.light();
      final tinted = base.copyWith(primary: Colors.pink);

      expect(tinted.primary, Colors.pink);
      expect(tinted.surface, base.surface); // untouched fields preserved
    });

    test('lerp at t=0 and t=1 returns the boundary colors', () {
      final light = DesignSystemColors.light();
      final dark = DesignSystemColors.dark();

      final at0 = light.lerp(dark, 0);
      final at1 = light.lerp(dark, 1);

      expect(at0.background, light.background);
      expect(at1.background, dark.background);
    });

    test('lerp falls back to `this` when given an incompatible extension',
        () {
      final light = DesignSystemColors.light();
      // ThemeExtension<T>.lerp's contract: if `other` isn't the same type,
      // implementations should return `this` unchanged rather than throw.
      final result = light.lerp(null, 0.5);
      expect(result, same(light));
    });
  });

  group('AppColors.of(context)', () {
    testWidgets('falls back to DesignSystemColors.dark() when no '
        'ThemeExtension is registered on the ambient Theme', (tester) async {
      late DesignSystemColors resolved;

      await tester.pumpWidget(
        MaterialApp(
          // Deliberately a bare ThemeData with no `extensions:` entry.
          theme: ThemeData(),
          home: Builder(
            builder: (context) {
              resolved = AppColors.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final fallback = DesignSystemColors.dark();
      expect(resolved.background, fallback.background);
      expect(resolved.textPrimary, fallback.textPrimary);
    });

    testWidgets('returns the registered DesignSystemColors extension when '
        'present on the ambient Theme', (tester) async {
      late DesignSystemColors resolved;
      final custom = DesignSystemColors.light().copyWith(
        primary: const Color(0xFF00FF00),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [custom]),
          home: Builder(
            builder: (context) {
              resolved = AppColors.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved.primary, const Color(0xFF00FF00));
    });
  });
}
