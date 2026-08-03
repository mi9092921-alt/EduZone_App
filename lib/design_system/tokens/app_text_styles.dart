import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle display = TextStyle(
    fontSize: 36,
    height: 1.22,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    height: 1.29,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 22,
    height: 1.36,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 18,
    height: 1.44,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static const TextStyle h4 = TextStyle(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    height: 1.33,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  /// Tiny bold badge/pill label (10px) -- course "Free" ribbon, todo
  /// priority pill. Color is intentionally omitted; call sites set it via
  /// .copyWith(color: ...) since it varies per badge.
  static const TextStyle labelTiny = TextStyle(
    fontSize: 10,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    height: 1.45,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  static const TextStyle label = TextStyle(
    fontSize: 14,
    height: 1.43,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  static TextStyle get code => GoogleFonts.jetBrainsMono(
    fontSize: 13,
    height: 1.54,
    fontWeight: FontWeight.w400,
    color: AppColors.onBackgroundPrimary,
  );

  static const TextStyle overline = TextStyle(
    fontSize: 11,
    height: 1.45,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: AppColors.onBackgroundMuted,
  );

  static TextStyle get h3OnSurface =>
      h3.copyWith(color: AppColors.onSurfacePrimary);

  static TextStyle get bodyMediumOnSurface =>
      bodyMedium.copyWith(color: AppColors.onSurfaceSecondary);

  /// Bold, tightly-tracked wordmark style used for the animated "EduZone"
  /// splash-screen logo. Color is intentionally omitted -- call sites set
  /// it via .copyWith(color: ...) since the splash screen swaps between a
  /// light and dark variant.
  static const TextStyle brandLogo = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );

  static const TextStyle bodyMediumAr = TextStyle(
    fontSize: 15,
    height: 1.7,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static const TextStyle labelAr = TextStyle(
    fontSize: 14,
    height: 1.6,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );
}

TextTheme buildAppTextTheme({
  required Locale locale,
  required Brightness brightness,
  required Color primaryTextColor,
  required Color secondaryTextColor,
  required Color mutedTextColor,
}) {
  final base = brightness == Brightness.dark
      ? Typography.material2021().white
      : Typography.material2021().black;

  final localized = locale.languageCode == 'ar'
      ? GoogleFonts.cairoTextTheme(base)
      : GoogleFonts.outfitTextTheme(base);

  return localized.copyWith(
    displayLarge: localized.displayLarge?.copyWith(
      fontSize: AppTextStyles.display.fontSize,
      height: AppTextStyles.display.height,
      fontWeight: AppTextStyles.display.fontWeight,
      letterSpacing: AppTextStyles.display.letterSpacing,
      color: primaryTextColor,
    ),
    headlineLarge: localized.headlineLarge?.copyWith(
      fontSize: AppTextStyles.h1.fontSize,
      height: AppTextStyles.h1.height,
      fontWeight: AppTextStyles.h1.fontWeight,
      letterSpacing: AppTextStyles.h1.letterSpacing,
      color: primaryTextColor,
    ),
    headlineMedium: localized.headlineMedium?.copyWith(
      fontSize: AppTextStyles.h2.fontSize,
      height: AppTextStyles.h2.height,
      fontWeight: AppTextStyles.h2.fontWeight,
      letterSpacing: AppTextStyles.h2.letterSpacing,
      color: primaryTextColor,
    ),
    headlineSmall: localized.headlineSmall?.copyWith(
      fontSize: AppTextStyles.h3.fontSize,
      height: AppTextStyles.h3.height,
      fontWeight: AppTextStyles.h3.fontWeight,
      letterSpacing: AppTextStyles.h3.letterSpacing,
      color: primaryTextColor,
    ),
    titleLarge: localized.titleLarge?.copyWith(
      fontSize: AppTextStyles.h2.fontSize,
      height: AppTextStyles.h2.height,
      fontWeight: AppTextStyles.h2.fontWeight,
      letterSpacing: 0,
      color: primaryTextColor,
    ),
    titleMedium: localized.titleMedium?.copyWith(
      fontSize: AppTextStyles.h3.fontSize,
      height: AppTextStyles.h3.height,
      fontWeight: AppTextStyles.h3.fontWeight,
      letterSpacing: 0,
      color: primaryTextColor,
    ),
    bodyLarge: localized.bodyLarge?.copyWith(
      fontSize: AppTextStyles.bodyLarge.fontSize,
      height: AppTextStyles.bodyLarge.height,
      letterSpacing: AppTextStyles.bodyLarge.letterSpacing,
      color: secondaryTextColor,
    ),
    bodyMedium: localized.bodyMedium?.copyWith(
      fontSize: AppTextStyles.bodyMedium.fontSize,
      height: AppTextStyles.bodyMedium.height,
      letterSpacing: AppTextStyles.bodyMedium.letterSpacing,
      color: secondaryTextColor,
    ),
    bodySmall: localized.bodySmall?.copyWith(
      fontSize: AppTextStyles.bodySmall.fontSize,
      height: AppTextStyles.bodySmall.height,
      letterSpacing: AppTextStyles.bodySmall.letterSpacing,
      color: mutedTextColor,
    ),
    labelLarge: localized.labelLarge?.copyWith(
      fontSize: AppTextStyles.label.fontSize,
      height: AppTextStyles.label.height,
      fontWeight: AppTextStyles.label.fontWeight,
      letterSpacing: AppTextStyles.label.letterSpacing,
      color: primaryTextColor,
    ),
    labelSmall: localized.labelSmall?.copyWith(
      fontSize: AppTextStyles.labelSmall.fontSize,
      height: AppTextStyles.labelSmall.height,
      fontWeight: AppTextStyles.labelSmall.fontWeight,
      letterSpacing: AppTextStyles.labelSmall.letterSpacing,
      color: mutedTextColor,
    ),
  );
}
