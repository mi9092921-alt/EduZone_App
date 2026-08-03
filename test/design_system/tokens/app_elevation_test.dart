import 'package:app/design_system/tokens/app_elevation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppElevation', () {
    test('scale is strictly increasing from none to xl', () {
      final scale = [
        AppElevation.none,
        AppElevation.xs,
        AppElevation.sm,
        AppElevation.md,
        AppElevation.lg,
        AppElevation.xl,
      ];

      for (var i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]));
      }
    });

    test('none is exactly zero', () {
      expect(AppElevation.none, 0);
    });

    test('shadow getters return the matching AppShadows level', () {
      expect(AppElevation.shadowSm, same(AppShadows.level1));
      expect(AppElevation.shadowMd, same(AppShadows.level2));
      expect(AppElevation.shadowLg, same(AppShadows.level3));
    });

    test('shadowNone returns an empty list', () {
      expect(AppElevation.shadowNone, isEmpty);
    });

    test('AppShadows levels escalate in blur radius (deeper = softer/larger)', () {
      double maxBlur(List<BoxShadow> shadows) =>
          shadows.map((s) => s.blurRadius).reduce((a, b) => a > b ? a : b);

      expect(maxBlur(AppShadows.level1), lessThan(maxBlur(AppShadows.level2)));
      expect(maxBlur(AppShadows.level2), lessThan(maxBlur(AppShadows.level3)));
    });

    group('cardDecoration', () {
      test('defaults to elevated with AppColors.surface and AppRadius.md', () {
        final decoration = AppElevation.cardDecoration();

        expect(decoration.boxShadow, AppShadows.level1);
        expect(
          decoration.borderRadius,
          BorderRadius.circular(16.0), // AppRadius.md
        );
      });

      test('elevated: false produces no shadow', () {
        final decoration = AppElevation.cardDecoration(elevated: false);
        expect(decoration.boxShadow, isNull);
      });

      test('honors a custom radius and color override', () {
        const customColor = Color(0xFF123456);
        final decoration = AppElevation.cardDecoration(
          radius: 4.0,
          color: customColor,
        );

        expect(decoration.color, customColor);
        expect(decoration.borderRadius, BorderRadius.circular(4.0));
      });
    });
  });
}
