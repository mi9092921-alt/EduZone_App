import 'package:flutter/material.dart';

/// Detects the visual text direction of arbitrary user-generated content
/// (todo titles, names, comments, etc.) independently of the app's current
/// UI locale.
///
/// The app's `Directionality` is derived from [AppLocale] (see
/// `app_providers.dart`), which only reflects the *interface* language
/// (e.g. `en`/`ar`). It does NOT reflect the language of free-form content a
/// user types, so an Arabic todo title typed while the app UI is set to
/// English would otherwise be forced left-to-right and look broken.
///
/// This class inspects the first strongly-directional character in the
/// given text (skipping neutral characters such as digits, punctuation and
/// whitespace) and returns the matching [TextDirection], following the
/// standard Unicode Bidirectional Algorithm (UAX #9) "first-strong"
/// heuristic used by `intl`'s `Bidi.estimateDirectionOfText`.
abstract class TextDirectionDetector {
  // Unicode ranges for scripts that are written right-to-left.
  // Arabic, Arabic Supplement, Arabic Extended-A/B, Arabic Presentation Forms A/B,
  // Hebrew.
  static final RegExp _rtlChar = RegExp(
    r'[\u0590-\u05FF\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF'
    r'\uFB1D-\uFDFF\uFE70-\uFEFF]',
  );

  // Unicode ranges for common left-to-right scripts (Latin, Cyrillic, etc.).
  static final RegExp _ltrChar = RegExp(
    r'[A-Za-z\u00C0-\u024F\u0400-\u04FF]',
  );

  /// Returns [TextDirection.rtl] or [TextDirection.ltr] based on the first
  /// strongly-directional character found in [text].
  ///
  /// Falls back to [fallback] (defaults to [TextDirection.ltr]) when the
  /// text is empty or contains no strongly-directional characters (e.g. a
  /// string made only of digits or emoji).
  static TextDirection detect(
    String? text, {
    TextDirection fallback = TextDirection.ltr,
  }) {
    if (text == null || text.isEmpty) return fallback;

    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (_rtlChar.hasMatch(char)) return TextDirection.rtl;
      if (_ltrChar.hasMatch(char)) return TextDirection.ltr;
      // Neutral character (digit, punctuation, whitespace, emoji) -> keep scanning.
    }
    return fallback;
  }

  /// Convenience helper returning [TextAlign.right] / [TextAlign.left]
  /// (rather than `start`/`end`) for widgets that need an explicit
  /// alignment independent of an ambient `Directionality`.
  static TextAlign detectAlign(
    String? text, {
    TextDirection fallback = TextDirection.ltr,
  }) {
    return detect(text, fallback: fallback) == TextDirection.rtl
        ? TextAlign.right
        : TextAlign.left;
  }

  /// True if [text]'s detected direction is RTL.
  static bool isRtl(String? text) => detect(text) == TextDirection.rtl;
}