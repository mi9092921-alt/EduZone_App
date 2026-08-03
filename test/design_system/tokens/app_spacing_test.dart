import 'package:app/design_system/tokens/app_spacing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSpacing', () {
    test('scale is strictly increasing from xs2 to xl12', () {
      final scale = [
        AppSpacing.xs2,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl2,
        AppSpacing.xl3,
        AppSpacing.xl4,
        AppSpacing.xl6,
        AppSpacing.xl12,
      ];

      for (var i = 1; i < scale.length; i++) {
        expect(
          scale[i],
          greaterThan(scale[i - 1]),
          reason:
              'Spacing step $i (${scale[i]}) must be strictly greater than '
              'step ${i - 1} (${scale[i - 1]}) to keep the scale monotonic',
        );
      }
    });

    test('base values match the documented design scale', () {
      expect(AppSpacing.xs2, 4.0);
      expect(AppSpacing.xs, 6.0);
      expect(AppSpacing.sm, 8.0);
      expect(AppSpacing.md, 12.0);
      expect(AppSpacing.lg, 16.0);
      expect(AppSpacing.xl, 24.0);
      expect(AppSpacing.xl2, 32.0);
      expect(AppSpacing.xl3, 40.0);
      expect(AppSpacing.xl4, 48.0);
      expect(AppSpacing.xl6, 64.0);
      expect(AppSpacing.xl12, 96.0);
    });

    test('semantic aliases point at the correct base token', () {
      expect(AppSpacing.buttonPaddingH, AppSpacing.lg);
      expect(AppSpacing.cardPadding, AppSpacing.xl);
      expect(AppSpacing.pagePadding, AppSpacing.lg);
      expect(AppSpacing.sectionSpacing, AppSpacing.xl2);
      expect(AppSpacing.iconGap, AppSpacing.sm);
      expect(AppSpacing.chipInnerPadding, AppSpacing.xs);
    });

    test('all values are non-negative', () {
      for (final value in [
        AppSpacing.xs2,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl2,
        AppSpacing.xl3,
        AppSpacing.xl4,
        AppSpacing.xl6,
        AppSpacing.xl12,
        AppSpacing.buttonPaddingV,
      ]) {
        expect(value, greaterThanOrEqualTo(0));
      }
    });
  });
}
