import 'package:app/features/auth/presentation/screens/splash/splash_brand_metrics.dart';
import 'package:app/features/auth/presentation/screens/splash/splash_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const style = TextStyle(fontSize: 30, fontWeight: FontWeight.w800);

  group('SplashBrandMetrics.measure', () {
    test('produces one width and one offset per letter of "cation"', () {
      final metrics = SplashBrandMetrics.measure(style);

      expect(metrics.letterWidths, hasLength(kSplashCationLetterCount));
      expect(metrics.letterOffsets, hasLength(kSplashCationLetterCount));
    });

    test('all measured widths are positive', () {
      final metrics = SplashBrandMetrics.measure(style);

      for (final width in metrics.letterWidths) {
        expect(width, greaterThan(0));
      }
      expect(metrics.spaceWidth, greaterThan(0));
    });

    test('offsets are the running cumulative sum of the preceding widths', () {
      final metrics = SplashBrandMetrics.measure(style);

      expect(metrics.letterOffsets.first, 0);

      double running = 0;
      for (var i = 0; i < kSplashCationLetterCount; i++) {
        expect(metrics.letterOffsets[i], closeTo(running, 0.001));
        running += metrics.letterWidths[i];
      }
    });

    test('fullCationWidth equals the sum of all letter widths', () {
      final metrics = SplashBrandMetrics.measure(style);

      final expectedTotal = metrics.letterWidths.fold<double>(
        0,
        (sum, w) => sum + w,
      );

      expect(metrics.fullCationWidth, closeTo(expectedTotal, 0.001));
    });

    test('a larger font size produces proportionally larger measurements', () {
      const smallStyle = TextStyle(fontSize: 10);
      const bigStyle = TextStyle(fontSize: 60);

      final small = SplashBrandMetrics.measure(smallStyle);
      final big = SplashBrandMetrics.measure(bigStyle);

      expect(big.fullCationWidth, greaterThan(small.fullCationWidth));
      expect(big.spaceWidth, greaterThan(small.spaceWidth));
    });
  });
}
