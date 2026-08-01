import 'package:flutter/material.dart';

class AppDuration {
  AppDuration._();

  static const Duration instant  = Duration.zero;
  static const Duration fast     = Duration(milliseconds: 100);
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration enter    = Duration(milliseconds: 250);
  static const Duration exit_    = Duration(milliseconds: 200);
  static const Duration bounce   = Duration(milliseconds: 300);
  static const Duration shake    = Duration(milliseconds: 300);
}

class AppCurves {
  AppCurves._();

  static const Curve standard = Curves.easeInOut;
  static const Curve enter    = Curves.easeOutCubic;
  static const Curve exit_    = Curves.easeInCubic;
  static const Curve bounce   = Curves.elasticOut;
  static const Curve fast     = Curves.easeOut;
}
