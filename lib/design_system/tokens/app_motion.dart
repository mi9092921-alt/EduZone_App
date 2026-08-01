import 'package:flutter/material.dart';

/// Standard motion and animation tokens for consistently smooth transitions.
class AppMotion {
  AppMotion._();

  // Durations
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration shimmer = Duration(milliseconds: 1500);

  // Curves
  static const Curve standard = Curves.easeInOutCubic;
  static const Curve decelerate = Curves.easeOutCubic;
  static const Curve accelerate = Curves.easeInCubic;
  static const Curve sharp = Curves.easeInOutQuart;
  static const Curve bounce = Curves.elasticOut;

  // Common animation configurations
  static const double hoverScale = 1.02;
  static const double pressedScale = 0.98;
}
