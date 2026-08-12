import 'package:flutter/widgets.dart';

import 'splash_constants.dart';

/// Result of measuring the "cation" letters and the following space, at a
/// given [TextStyle].
///
/// Extracted from the private `_measureLetters()` method that used to live
/// on `_SplashScreenState` so the measurement math can be unit-tested in
/// isolation from animation setup and the widget tree.
@immutable
class SplashBrandMetrics {
  final List<double> letterWidths;
  final List<double> letterOffsets;
  final double fullCationWidth;
  final double spaceWidth;

  const SplashBrandMetrics({
    required this.letterWidths,
    required this.letterOffsets,
    required this.fullCationWidth,
    required this.spaceWidth,
  });

  /// Measures each letter of [kSplashCation] plus a trailing space, laid
  /// out with [style], and returns the per-letter widths/cumulative
  /// offsets needed to animate the letter-collapse effect.
  factory SplashBrandMetrics.measure(TextStyle style) {
    final painter = TextPainter(textDirection: TextDirection.ltr);

    final letterWidths = List<double>.generate(kSplashCationLetterCount, (i) {
      painter.text = TextSpan(text: kSplashCation[i], style: style);
      painter.layout();
      return painter.width;
    });

    double running = 0;
    final letterOffsets = List<double>.generate(kSplashCationLetterCount, (i) {
      final offset = running;
      running += letterWidths[i];
      return offset;
    });
    final fullCationWidth = running;

    painter.text = TextSpan(text: ' ', style: style);
    painter.layout();
    final spaceWidth = painter.width;

    return SplashBrandMetrics(
      letterWidths: letterWidths,
      letterOffsets: letterOffsets,
      fullCationWidth: fullCationWidth,
      spaceWidth: spaceWidth,
    );
  }
}
