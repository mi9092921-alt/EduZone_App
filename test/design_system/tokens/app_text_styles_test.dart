import 'package:app/design_system/tokens/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTextStyles scale', () {
    test('font sizes descend from display down to labelSmall', () {
      final scale = [
        AppTextStyles.display,
        AppTextStyles.h1,
        AppTextStyles.h2,
        AppTextStyles.h3,
        AppTextStyles.h4,
        AppTextStyles.bodyLarge, // same size as h4 (16) by design
      ];

      for (var i = 1; i < scale.length; i++) {
        expect(
          scale[i].fontSize,
          lessThanOrEqualTo(scale[i - 1].fontSize!),
          reason: 'Style index $i should not be larger than the previous '
              'one in the visual hierarchy',
        );
      }

      expect(AppTextStyles.bodyMedium.fontSize, 14);
      expect(AppTextStyles.bodySmall.fontSize, 12);
      expect(AppTextStyles.labelSmall.fontSize, 11);
    });

    test('heading styles are bolder than body styles', () {
      expect(
        AppTextStyles.h1.fontWeight!.value,
        greaterThanOrEqualTo(AppTextStyles.bodyMedium.fontWeight!.value),
      );
      expect(
        AppTextStyles.h2.fontWeight!.value,
        greaterThanOrEqualTo(AppTextStyles.bodyMedium.fontWeight!.value),
      );
    });

    test('Arabic-specific variants use a taller line height than their '
        'Latin counterparts (Arabic script needs more vertical room)', () {
      expect(AppTextStyles.bodyMediumAr.height,
          greaterThan(AppTextStyles.bodyMedium.height!));
      expect(AppTextStyles.labelAr.height, greaterThan(AppTextStyles.label.height!));
    });

    test('h3OnSurface and bodyMediumOnSurface only override color', () {
      final h3OnSurface = AppTextStyles.h3OnSurface;
      expect(h3OnSurface.fontSize, AppTextStyles.h3.fontSize);
      expect(h3OnSurface.fontWeight, AppTextStyles.h3.fontWeight);
      expect(h3OnSurface.color, isNotNull);

      final bodyOnSurface = AppTextStyles.bodyMediumOnSurface;
      expect(bodyOnSurface.fontSize, AppTextStyles.bodyMedium.fontSize);
      expect(bodyOnSurface.color, isNotNull);
    });

    test('code style is monospace-flagged via a distinct font family', () {
      // GoogleFonts.jetBrainsMono always sets a fontFamily; we don't assert
      // the exact family name (that's Google Fonts' contract, not ours),
      // just that this style is deliberately NOT null/generic.
      expect(AppTextStyles.code.fontFamily, isNotNull);
      expect(AppTextStyles.code.fontSize, 13);
    });
  });

  group('buildAppTextTheme', () {
    const primaryColor = Color(0xFF111111);
    const secondaryColor = Color(0xFF222222);
    const mutedColor = Color(0xFF333333);

    test('applies the given colors to the corresponding TextTheme roles', () {
      final theme = buildAppTextTheme(
        locale: const Locale('en'),
        brightness: Brightness.light,
        primaryTextColor: primaryColor,
        secondaryTextColor: secondaryColor,
        mutedTextColor: mutedColor,
      );

      expect(theme.headlineLarge?.color, primaryColor);
      expect(theme.titleLarge?.color, primaryColor);
      expect(theme.bodyLarge?.color, secondaryColor);
      expect(theme.bodyMedium?.color, secondaryColor);
      expect(theme.bodySmall?.color, mutedColor);
      expect(theme.labelSmall?.color, mutedColor);
    });

    test('maps AppTextStyles sizes onto the returned TextTheme', () {
      final theme = buildAppTextTheme(
        locale: const Locale('en'),
        brightness: Brightness.light,
        primaryTextColor: primaryColor,
        secondaryTextColor: secondaryColor,
        mutedTextColor: mutedColor,
      );

      expect(theme.displayLarge?.fontSize, AppTextStyles.display.fontSize);
      expect(theme.headlineLarge?.fontSize, AppTextStyles.h1.fontSize);
      expect(theme.headlineMedium?.fontSize, AppTextStyles.h2.fontSize);
      expect(theme.headlineSmall?.fontSize, AppTextStyles.h3.fontSize);
    });

    test('uses Cairo font family consistently for both Arabic and English locales', () {
      final en = buildAppTextTheme(
        locale: const Locale('en'),
        brightness: Brightness.light,
        primaryTextColor: primaryColor,
        secondaryTextColor: secondaryColor,
        mutedTextColor: mutedColor,
      );
      final ar = buildAppTextTheme(
        locale: const Locale('ar'),
        brightness: Brightness.light,
        primaryTextColor: primaryColor,
        secondaryTextColor: secondaryColor,
        mutedTextColor: mutedColor,
      );

      // Cairo covers both Arabic + Latin in one bundled typeface
      expect(en.bodyMedium?.fontFamily, 'Cairo');
      expect(ar.bodyMedium?.fontFamily, 'Cairo');
    });

    test('does not throw for either brightness', () {
      expect(
        () => buildAppTextTheme(
          locale: const Locale('en'),
          brightness: Brightness.dark,
          primaryTextColor: primaryColor,
          secondaryTextColor: secondaryColor,
          mutedTextColor: mutedColor,
        ),
        returnsNormally,
      );
    });
  });
}
