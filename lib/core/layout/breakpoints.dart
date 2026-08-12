import 'package:flutter/material.dart';

class Breakpoints {
  static const double mobile  = 600;
  static const double tablet  = 900;
  static const double desktop = 1200;

  static bool isMobile(BuildContext ctx)  => MediaQuery.sizeOf(ctx).width < mobile;
  static bool isTablet(BuildContext ctx)  => MediaQuery.sizeOf(ctx).width >= mobile
                                          && MediaQuery.sizeOf(ctx).width < desktop;
  static bool isDesktop(BuildContext ctx) => MediaQuery.sizeOf(ctx).width >= desktop;
}
