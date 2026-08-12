import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_elevation.dart';

/// Custom theme extension for CourseCard to handle style-specific theming.
class CourseCardTheme extends ThemeExtension<CourseCardTheme> {
  final Color? backgroundColor;
  final Color? borderColor;
  final double? elevation;
  final double? borderRadius;

  const CourseCardTheme({
    this.backgroundColor,
    this.borderColor,
    this.elevation,
    this.borderRadius,
  });

  @override
  CourseCardTheme copyWith({
    Color? backgroundColor,
    Color? borderColor,
    double? elevation,
    double? borderRadius,
  }) {
    return CourseCardTheme(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
      elevation: elevation ?? this.elevation,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  @override
  CourseCardTheme lerp(ThemeExtension<CourseCardTheme>? other, double t) {
    if (other is! CourseCardTheme) return this;
    return CourseCardTheme(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      elevation: Tween<double>(begin: elevation, end: other.elevation).transform(t),
      borderRadius: Tween<double>(begin: borderRadius, end: other.borderRadius).transform(t),
    );
  }

  static CourseCardTheme light() {
    return const CourseCardTheme(
      backgroundColor: AppColors.lightSurface,
      borderColor: AppColors.lightBorder,
      elevation: AppElevation.sm,
      borderRadius: 12.0,
    );
  }

  static CourseCardTheme dark() {
    return const CourseCardTheme(
      backgroundColor: AppColors.darkSurface,
      borderColor: AppColors.darkBorder,
      elevation: AppElevation.md,
      borderRadius: 12.0,
    );
  }
}

/// Helper extension on BuildContext to easily access custom themes.
extension AppThemeX on BuildContext {
  CourseCardTheme get courseCardTheme => Theme.of(this).extension<CourseCardTheme>()!;
}
