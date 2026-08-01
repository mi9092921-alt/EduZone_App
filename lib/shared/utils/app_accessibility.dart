import 'package:flutter/material.dart';

/// Utilities for ensuring high-fidelity accessibility (WCAG AA) within the EduZone system.
class AppAccessibility {
  AppAccessibility._();

  /// Calculates the contrast ratio between two colors.
  /// Result is between 1.0 and 21.0.
  static double contrastRatio(Color a, Color b) {
    final l1 = a.computeLuminance();
    final l2 = b.computeLuminance();
    final brightest = l1 > l2 ? l1 : l2;
    final darkest = l1 > l2 ? l2 : l1;
    return (brightest + 0.05) / (darkest + 0.05);
  }

  /// Ensures a text color is readable against a background color.
  /// If the contrast ratio is below WCAG AA (4.5), it returns a high-contrast alternative.
  static Color ensureReadable(Color text, Color bg, {double minRatio = 4.5}) {
    final ratio = contrastRatio(text, bg);

    if (ratio < minRatio) {
      // If the background is bright, use black. If dark, use white.
      return bg.computeLuminance() > 0.5 
          ? Colors.black 
          : Colors.white;
    }
    return text;
  }

  /// Returns whether a color context is "Dark" based on luminance.
  static bool isDark(Color color) => color.computeLuminance() < 0.5;

  /// Returns a slightly adjusted color (darker or lighter) to improve contrast.
  static Color adjustForContrast(Color color, Color bg) {
    final ratio = contrastRatio(color, bg);
    if (ratio >= 4.5) return color;

    final hls = HSLColor.fromColor(color);
    if (bg.computeLuminance() > 0.5) {
      // Darken text for light background
      return hls.withLightness((hls.lightness - 0.2).clamp(0, 1)).toColor();
    } else {
      // Lighten text for dark background
      return hls.withLightness((hls.lightness + 0.2).clamp(0, 1)).toColor();
    }
  }
}
