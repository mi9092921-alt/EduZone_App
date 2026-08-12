import 'dart:math' as math;
import 'package:app/design_system/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double calculateLuminance(Color color) {
  double transform(double value) {
    return value <= 0.04045
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = transform(color.r);
  final g = transform(color.g);
  final b = transform(color.b);

  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double calculateContrastRatio(Color color1, Color color2) {
  final l1 = calculateLuminance(color1);
  final l2 = calculateLuminance(color2);

  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);

  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('DesignSystemColors WCAG 2.1 AA Contrast Ratio Tests', () {
    test('Light theme text colors meet minimum 4.5:1 contrast on surface', () {
      final light = DesignSystemColors.light();

      final primaryRatio =
          calculateContrastRatio(light.textPrimary, light.surface);
      final secondaryRatio =
          calculateContrastRatio(light.textSecondary, light.surface);
      final mutedRatio = calculateContrastRatio(light.textMuted, light.surface);
      final successTextRatio =
          calculateContrastRatio(light.successText, light.surface);
      final warningTextRatio =
          calculateContrastRatio(light.warningText, light.surface);
      final errorTextRatio =
          calculateContrastRatio(light.errorText, light.surface);

      expect(primaryRatio, greaterThanOrEqualTo(4.5),
          reason: 'textPrimary contrast ratio $primaryRatio is below 4.5:1');
      expect(secondaryRatio, greaterThanOrEqualTo(4.5),
          reason:
              'textSecondary contrast ratio $secondaryRatio is below 4.5:1');
      expect(mutedRatio, greaterThanOrEqualTo(4.5),
          reason: 'textMuted contrast ratio $mutedRatio is below 4.5:1');
      expect(successTextRatio, greaterThanOrEqualTo(4.5),
          reason:
              'successText contrast ratio $successTextRatio is below 4.5:1');
      expect(warningTextRatio, greaterThanOrEqualTo(4.5),
          reason:
              'warningText contrast ratio $warningTextRatio is below 4.5:1');
      expect(errorTextRatio, greaterThanOrEqualTo(4.5),
          reason: 'errorText contrast ratio $errorTextRatio is below 4.5:1');
    });

    test('Dark theme text colors meet minimum 4.5:1 contrast on surface', () {
      final dark = DesignSystemColors.dark();

      final primaryRatio = calculateContrastRatio(dark.textPrimary, dark.surface);
      final secondaryRatio =
          calculateContrastRatio(dark.textSecondary, dark.surface);
      final mutedRatio = calculateContrastRatio(dark.textMuted, dark.surface);
      final successTextRatio =
          calculateContrastRatio(dark.successText, dark.surface);
      final warningTextRatio =
          calculateContrastRatio(dark.warningText, dark.surface);
      final errorTextRatio = calculateContrastRatio(dark.errorText, dark.surface);

      expect(primaryRatio, greaterThanOrEqualTo(4.5),
          reason: 'textPrimary contrast ratio $primaryRatio is below 4.5:1');
      expect(secondaryRatio, greaterThanOrEqualTo(4.5),
          reason:
              'textSecondary contrast ratio $secondaryRatio is below 4.5:1');
      expect(mutedRatio, greaterThanOrEqualTo(4.5),
          reason: 'textMuted contrast ratio $mutedRatio is below 4.5:1');
      expect(successTextRatio, greaterThanOrEqualTo(4.5),
          reason:
              'successText contrast ratio $successTextRatio is below 4.5:1');
      expect(warningTextRatio, greaterThanOrEqualTo(4.5),
          reason:
              'warningText contrast ratio $warningTextRatio is below 4.5:1');
      expect(errorTextRatio, greaterThanOrEqualTo(4.5),
          reason: 'errorText contrast ratio $errorTextRatio is below 4.5:1');
    });
  });
}
