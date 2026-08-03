import 'package:app/design_system/tokens/app_radius.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRadius', () {
    test('scale is strictly increasing from xs to full', () {
      final scale = [
        AppRadius.xs,
        AppRadius.sm,
        AppRadius.md,
        AppRadius.lg,
        AppRadius.xl,
        AppRadius.full,
      ];

      for (var i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]));
      }
    });

    test('full is large enough to fully round any realistic component', () {
      // "full" is meant to produce pill/circle shapes regardless of the
      // widget's size, so it must comfortably exceed any element dimension
      // used elsewhere in the design system (e.g. AppSizes.avatarLg = 64).
      expect(AppRadius.full, greaterThanOrEqualTo(999.0));
    });

    test('each *Border constant wraps the matching double radius uniformly', () {
      final pairs = <BorderRadius, double>{
        AppRadius.xsBorder: AppRadius.xs,
        AppRadius.smBorder: AppRadius.sm,
        AppRadius.mdBorder: AppRadius.md,
        AppRadius.lgBorder: AppRadius.lg,
        AppRadius.xlBorder: AppRadius.xl,
        AppRadius.fullBorder: AppRadius.full,
      };

      pairs.forEach((border, radius) {
        expect(border.topLeft, Radius.circular(radius));
        expect(border.topRight, Radius.circular(radius));
        expect(border.bottomLeft, Radius.circular(radius));
        expect(border.bottomRight, Radius.circular(radius));
      });
    });
  });
}
