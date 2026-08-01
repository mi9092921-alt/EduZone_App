import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_elevation.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';
import 'app_theme_extensions.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light(Locale locale) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          primaryContainer: AppColors.primarySoft,
          onPrimaryContainer: AppColors.primaryPressed,
          surface: AppColors.lightSurface,
          surfaceContainerLowest: AppColors.lightBackground,
          surfaceContainerLow: AppColors.lightSurface,
          surfaceContainerHighest: AppColors.lightSurface2,
          onSurface: AppColors.lightOnSurfacePrimary,
          onSurfaceVariant: AppColors.lightOnSurfaceSecondary,
          outline: AppColors.lightBorder,
          outlineVariant: AppColors.lightBorder,
          error: AppColors.error,
          onError: Colors.white,
        );

    return _buildThemeData(
      locale: locale,
      colorScheme: colorScheme,
      dividerColor: AppColors.lightBorder,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      extensions: [DesignSystemColors.light(), CourseCardTheme.light()],
    );
  }

  static ThemeData dark(Locale locale) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          primaryContainer: AppColors.darkSurface2,
          onPrimaryContainer: AppColors.darkOnSurfacePrimary,
          surface: AppColors.darkSurface,
          surfaceContainerLowest: AppColors.darkBackground,
          surfaceContainerLow: AppColors.darkSurface,
          surfaceContainerHighest: AppColors.darkSurface2,
          onSurface: AppColors.darkOnSurfacePrimary,
          onSurfaceVariant: AppColors.darkOnSurfaceSecondary,
          outline: AppColors.darkBorder,
          outlineVariant: AppColors.darkBorder,
          error: AppColors.error,
          onError: Colors.white,
        );

    return _buildThemeData(
      locale: locale,
      colorScheme: colorScheme,
      dividerColor: AppColors.darkBorder,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      extensions: [DesignSystemColors.dark(), CourseCardTheme.dark()],
    );
  }

  static ThemeData _buildThemeData({
    required Locale locale,
    required ColorScheme colorScheme,
    required Color dividerColor,
    required Color shadowColor,
    required SystemUiOverlayStyle systemOverlayStyle,
    required List<ThemeExtension<dynamic>> extensions,
  }) {
    final textTheme = buildAppTextTheme(
      locale: locale,
      brightness: colorScheme.brightness,
      primaryTextColor: colorScheme.onSurface,
      secondaryTextColor: colorScheme.onSurfaceVariant,
      mutedTextColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
      dividerColor: dividerColor,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 24),
        systemOverlayStyle: systemOverlayStyle,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: AppElevation.md,
        shadowColor: shadowColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.outlineVariant),
          borderRadius: AppRadius.mdBorder,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.outlineVariant),
          borderRadius: AppRadius.mdBorder,
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
          borderRadius: AppRadius.mdBorder,
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colorScheme.error, width: 2),
          borderRadius: AppRadius.mdBorder,
        ),
        labelStyle: textTheme.labelLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.buttonPaddingV,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
          textStyle: textTheme.labelLarge,
          elevation: AppElevation.none,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.buttonPaddingV,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
          side: BorderSide(color: colorScheme.primary, width: 1.5),
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smBorder),
        labelStyle: textTheme.labelLarge?.copyWith(color: colorScheme.primary),
        backgroundColor: colorScheme.primaryContainer,
        secondarySelectedColor: colorScheme.primary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelMedium?.copyWith(color: colorScheme.primary);
          }
          return textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary, size: 24);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant, size: 24);
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 72,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
        elevation: AppElevation.xl,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        elevation: AppElevation.xl,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearMinHeight: 4,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.outlineVariant;
        }),
      ),
      extensions: extensions,
    );
  }
}
