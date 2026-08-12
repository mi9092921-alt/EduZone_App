import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// The splash screen's background gradient. Extracted from
/// `splash_screen.dart` (previously a private `_GradientBackground`) so it
/// rebuilds independently of the logo/brand-name animations that wrap it.
class SplashGradientBackground extends StatelessWidget {
  const SplashGradientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  AppColors.darkBackground,
                  AppColors.darkSurface,
                  AppColors.darkSurface2,
                ]
              : [
                  AppColors.neutral50,
                  AppColors.primarySoft,
                  AppColors.primarySoft,
                ],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}
