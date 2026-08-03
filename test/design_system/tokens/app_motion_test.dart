import 'package:app/design_system/tokens/app_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppMotion', () {
    test('duration scale escalates from fast to shimmer', () {
      final scale = [
        AppMotion.fast,
        AppMotion.medium,
        AppMotion.slow,
        AppMotion.shimmer,
      ];

      for (var i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]));
      }
    });

    test('durations match the documented millisecond values', () {
      expect(AppMotion.fast, const Duration(milliseconds: 150));
      expect(AppMotion.medium, const Duration(milliseconds: 300));
      expect(AppMotion.slow, const Duration(milliseconds: 500));
      expect(AppMotion.shimmer, const Duration(milliseconds: 1500));
    });

    test('hoverScale grows and pressedScale shrinks relative to 1.0', () {
      expect(AppMotion.hoverScale, greaterThan(1.0));
      expect(AppMotion.pressedScale, lessThan(1.0));
    });

    test('curves are distinct instances for distinct semantic intents', () {
      expect(AppMotion.standard, isNot(AppMotion.decelerate));
      expect(AppMotion.decelerate, isNot(AppMotion.accelerate));
      expect(AppMotion.accelerate, isNot(AppMotion.sharp));
      expect(AppMotion.sharp, isNot(AppMotion.bounce));
    });
  });
}
