import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radius.dart';

class AppShadows {
  AppShadows._();

  // 🟢 Level 1 (Cards, list tiles)
  static List<BoxShadow> level1 = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  // 🔵 Level 2 (Modals / Elevated Cards / Popups)
  static List<BoxShadow> level2 = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  // 🔴 Level 3 (Floating / FAB / Overlays)
  static List<BoxShadow> level3 = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 40,
      offset: const Offset(0, 20),
    ),
  ];
}

class AppElevation {
  AppElevation._();

  static const double none = 0;
  static const double xs   = 1;
  static const double sm   = 2;
  static const double md   = 4;
  static const double lg   = 8;
  static const double xl   = 16;

  // Shadow Getters for component-specific usage
  static List<BoxShadow> get shadowSm => AppShadows.level1;
  static List<BoxShadow> get shadowMd => AppShadows.level2;
  static List<BoxShadow> get shadowLg => AppShadows.level3;
  static List<BoxShadow> get shadowNone => [];

  // Modern card decoration with layered shadows
  static BoxDecoration cardDecoration({
    bool elevated = true, 
    double radius = AppRadius.md,
    Color? color,
  }) => BoxDecoration(
    color: color ?? AppColors.surface,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: elevated ? AppShadows.level1 : null,
  );
}

