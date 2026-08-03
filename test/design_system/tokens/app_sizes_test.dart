import 'package:app/design_system/tokens/app_sizes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSizes', () {
    test('icon size scale is strictly increasing', () {
      final scale = [
        AppSizes.iconXs,
        AppSizes.iconSm,
        AppSizes.iconMd,
        AppSizes.iconLg,
        AppSizes.iconXl,
      ];

      for (var i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]));
      }
    });

    test('avatar size scale is strictly increasing', () {
      final scale = [AppSizes.avatarSm, AppSizes.avatarMd, AppSizes.avatarLg];

      for (var i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]));
      }
    });

    test('course card thumbnail fits within the card width', () {
      expect(
        AppSizes.courseCardThumbnailWidth,
        lessThanOrEqualTo(AppSizes.courseCardWidth),
      );
    });

    test('interactive touch targets meet a sane minimum (>= 44 logical px)',
        () {
      // Matches common accessibility guidance for minimum tap target size.
      expect(AppSizes.buttonHeight, greaterThanOrEqualTo(44.0));
      expect(AppSizes.inputHeight, greaterThanOrEqualTo(44.0));
    });

    test('all sizes are strictly positive', () {
      for (final value in [
        AppSizes.courseCardWidth,
        AppSizes.courseCardCompactHeight,
        AppSizes.courseCardThumbnailWidth,
        AppSizes.courseCardThumbnailHeight,
        AppSizes.iconXs,
        AppSizes.iconSm,
        AppSizes.iconMd,
        AppSizes.iconLg,
        AppSizes.iconXl,
        AppSizes.buttonHeight,
        AppSizes.inputHeight,
        AppSizes.avatarSm,
        AppSizes.avatarMd,
        AppSizes.avatarLg,
        AppSizes.progressHeight,
        AppSizes.appBarHeight,
        AppSizes.bottomNavHeight,
      ]) {
        expect(value, greaterThan(0));
      }
    });
  });
}
