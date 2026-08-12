import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ================= PRIMARY (Modern Blue - Vibrant)
  static const Color primary = Color(0xFF2563EB); // Main brand
  static const Color primaryHover = Color(0xFF1D4ED8);
  static const Color primaryPressed = Color(0xFF1E40AF);
  static const Color primarySoft = Color(0xFFDBEAFE);
  // نسخة غامقة من primarySoft لتمييز العنصر النشط في الـ Dark Mode
  // (primarySoft الأصلي لون فاتح جدًا ولا يصلح كخلفية في الثيم الغامق).
  static const Color primarySoftDark = Color(0xFF1E3A5F);

  // Accent (modern gradient support)
  static const Color accent = Color(0xFF7C3AED); // Purple modern touch

  // ================= NEUTRAL (Light Settings)
  static const Color lightBackground = Color(0xFFF1F5F9); // Slate 100 (More distinct)
  static const Color lightSurface = Color(0xFFFFFFFF);    // Pure White
  static const Color lightSurface2 = Color(0xFFE2E8F0);   // Slate 200
  static const Color lightBorder = Color(0xFFCBD5E1);     // Slate 300
  
  static const Color lightOnSurfacePrimary = Color(0xFF0F172A);
  static const Color lightOnSurfaceSecondary = Color(0xFF475569);
  static const Color lightOnSurfaceMuted = Color(0xFF5E6E85);

  // ================= NEUTRAL (Dark Settings)
  static const Color darkBackground = Color(0xFF020617); // Slate 950 (Deeper background)
  static const Color darkSurface = Color(0xFF0F172A);    // Slate 900 (Distinct surface)
  static const Color darkSurface2 = Color(0xFF1E293B);   // Slate 800
  static const Color darkBorder = Color(0xFF334155);     // Slate 700

  static const Color darkOnSurfacePrimary = Color(0xFFF9FAFB);
  static const Color darkOnSurfaceSecondary = Color(0xFF9CA3AF);
  static const Color darkOnSurfaceMuted = Color(0xFF8B96A8);

  // ================= SEMANTIC (Modern SaaS Style)
  static const Color success = Color(0xFF22C55E);
  static const Color successSoft = Color(0xFFDCFCE7);
  static const Color successDark = Color(0xFF14532D);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFF78350F);

  static const Color error = Color(0xFFEF4444);
  static const Color errorSoft = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFF7F1D1D);

  static const Color info = Color(0xFF38BDF8);

  // ================= LEGACY / FALLBACK (Pointing to dark by default)
  static const Color background = lightBackground;
  static const Color surface = lightSurface;
  static const Color surface2 = lightSurface2;
  static const Color border = lightBorder;
  static const Color textPrimary = lightOnSurfacePrimary;
  static const Color textSecondary = lightOnSurfaceSecondary;
  static const Color onSurfacePrimary = lightOnSurfacePrimary;
  static const Color onSurfaceSecondary = lightOnSurfaceSecondary;
  static const Color textMuted = onSurfaceSecondary;
  static const Color onSurfaceMuted = lightOnSurfaceMuted;
  
  static const Color onBackgroundPrimary = lightOnSurfacePrimary;
  static const Color onBackgroundSecondary = lightOnSurfaceSecondary;
  static const Color onBackgroundMuted = lightOnSurfaceMuted;

  // ================= NEUTRAL PALETTE (Standard Gray/Slate Scale)
  static const Color neutral50 = Color(0xFFF8FAFC);
  static const Color neutral100 = Color(0xFFF1F5F9);
  static const Color neutral200 = Color(0xFFE2E8F0);
  static const Color neutral300 = Color(0xFFCBD5E1);
  static const Color neutral400 = Color(0xFF94A3B8);
  static const Color neutral500 = Color(0xFF64748B);
  static const Color neutral600 = Color(0xFF475569);
  static const Color neutral700 = Color(0xFF334155);
  static const Color neutral800 = Color(0xFF1E293B);
  static const Color neutral900 = Color(0xFF0F172A);

  // ================= DESIGN TOKENS
  static const Color neutral0 = Colors.white;
  static const Color transparent = Colors.transparent;

  // ================= STATES
  static const Color hoverOverlay = Color(0x0FFFFFFF);
  static const Color focusRing = Color(0xFF60A5FA);

  // ================= OVERLAY / SCRIM
  // Black @ 30% alpha -- backdrop behind full-screen blocking loaders/dialogs.
  static const Color scrim = Color(0x4D000000);

  // ================= GRADIENTS (Modern UI trend)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      Color(0xFF2563EB),
      Color(0xFF7C3AED),
    ],
  );

  /// Helper to access theme-aware colors from the context.
  static DesignSystemColors of(BuildContext context) {
    return Theme.of(context).extension<DesignSystemColors>() ??
        DesignSystemColors.dark();
  }
}

/// A ThemeExtension that holds all semantic colors for the design system.
/// This allows the app to switch between light and dark backgrounds/surfaces
/// automatically when the theme changes.
class DesignSystemColors extends ThemeExtension<DesignSystemColors> {
  final Color background;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color primary;
  final Color primarySoft;
  final Color success;
  final Color successText;
  final Color warningText;
  final Color error;
  final Color errorText;

  const DesignSystemColors({
    required this.background,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.primarySoft,
    required this.success,
    required this.successText,
    required this.warningText,
    required this.error,
    required this.errorText,
  });

  factory DesignSystemColors.light() => const DesignSystemColors(
        background: AppColors.lightBackground,
        surface: AppColors.lightSurface,
        surface2: AppColors.lightSurface2,
        border: AppColors.lightBorder,
        textPrimary: AppColors.lightOnSurfacePrimary,
        textSecondary: AppColors.lightOnSurfaceSecondary,
        textMuted: AppColors.lightOnSurfaceMuted,
        primary: AppColors.primary,
        primarySoft: AppColors.primarySoft,
        success: AppColors.success,
        successText: AppColors.successDark,
        warningText: AppColors.warningDark,
        error: AppColors.error,
        errorText: AppColors.errorDark,
      );

  factory DesignSystemColors.dark() => const DesignSystemColors(
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        surface2: AppColors.darkSurface2,
        border: AppColors.darkBorder,
        textPrimary: AppColors.darkOnSurfacePrimary,
        textSecondary: AppColors.darkOnSurfaceSecondary,
        textMuted: AppColors.darkOnSurfaceMuted,
        primary: AppColors.primary,
        primarySoft: AppColors.primarySoftDark,
        success: AppColors.success,
        successText: AppColors.success,
        warningText: AppColors.warning,
        error: AppColors.error,
        errorText: AppColors.error,
      );

  @override
  DesignSystemColors copyWith({
    Color? background,
    Color? surface,
    Color? surface2,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? primary,
    Color? primarySoft,
    Color? success,
    Color? successText,
    Color? warningText,
    Color? error,
    Color? errorText,
  }) {
    return DesignSystemColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      success: success ?? this.success,
      successText: successText ?? this.successText,
      warningText: warningText ?? this.warningText,
      error: error ?? this.error,
      errorText: errorText ?? this.errorText,
    );
  }

  @override
  DesignSystemColors lerp(ThemeExtension<DesignSystemColors>? other, double t) {
    if (other is! DesignSystemColors) return this;
    return DesignSystemColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      successText: Color.lerp(successText, other.successText, t)!,
      warningText: Color.lerp(warningText, other.warningText, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorText: Color.lerp(errorText, other.errorText, t)!,
    );
  }
}
