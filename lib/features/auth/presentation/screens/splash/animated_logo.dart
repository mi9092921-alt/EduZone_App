import 'dart:ui';

import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

import 'splash_constants.dart';

/// The animated glassmorphism logo shown on the splash screen. Extracted
/// from `splash_screen.dart` (previously a private `_AnimatedLogo`) so it
/// rebuilds independently — it only listens to [main] and [pulse], never
/// to the brand-name letter animations.
class SplashAnimatedLogo extends StatelessWidget {
  final AnimationController main;
  final AnimationController pulse;
  final Animation<double> opacity;
  final Animation<double> translateY;
  final Animation<double> scaleBase;
  final Animation<double> logoPulse;
  final Animation<double> wobble;

  const SplashAnimatedLogo({
    super.key,
    required this.main,
    required this.pulse,
    required this.opacity,
    required this.translateY,
    required this.scaleBase,
    required this.logoPulse,
    required this.wobble,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      // ✅ يستمع للاثنين فقط — لا يعيد بناء بقية الشجرة
      animation: Listenable.merge([main, pulse]),
      builder: (context, child) {
        final scale = scaleBase.value * logoPulse.value;

        // Transform.translate + rotate + scale منفصلين —
        // Flutter يدمجهم تلقائياً في layer واحدة (repaint boundary)
        // وهذا أكثر استقراراً من Matrix4 cascade API المتغيرة
        return Semantics(
          label: 'EduZone logo', // check-ignore
          child: Opacity(
            opacity: opacity.value,
            child: Transform.translate(
              offset: Offset(0, translateY.value),
              child: Transform.rotate(
                angle: wobble.value,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: SplashConstants.logoSize,
                    height: SplashConstants.logoSize,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(SplashConstants.logoRadius),
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.topStart,
                        end: AlignmentDirectional.bottomEnd,
                        colors: isDark
                            ? [
                                AppColors.darkSurface.withValues(alpha: 0.75),
                                AppColors.darkSurface2.withValues(alpha: 0.35),
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.75),
                                Colors.white.withValues(alpha: 0.35),
                              ],
                      ),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder.withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.9),
                        width: 1.5,
                      ),
                      boxShadow: AppShadows.level2,
                    ),
                    // ✅ Glassmorphism حقيقي بـ BackdropFilter
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(SplashConstants.logoRadius),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            begin: AlignmentDirectional.topStart,
                            end: AlignmentDirectional.bottomEnd,
                            colors: [AppColors.primary, AppColors.accent],
                          ).createShader(
                            bounds,
                            textDirection: Directionality.of(context),
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            size: SplashConstants.logoIconSize,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
