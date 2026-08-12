import 'package:flutter/material.dart';

import 'splash_constants.dart';

/// The animated "EduZone" wordmark shown on the splash screen, where
/// "cation" slides/collapses letter-by-letter to reveal "Edu" + "Zone".
///
/// Extracted from `splash_screen.dart` (previously a private
/// `_AnimatedBrandName`) so it rebuilds independently of the logo — it
/// only listens to [main], never to the logo's separate pulse animation.
class SplashAnimatedBrandName extends StatelessWidget {
  final AnimationController main;
  final List<double> letterWidths;
  final List<double> letterOffsets;
  final double fullCationWidth;
  final double spaceWidth;
  final List<Animation<double>> letterOpacities;
  final List<Animation<double>> letterSlideX;
  final Animation<double> spaceOpacity;
  final Animation<double> finalTextScale;
  final TextStyle boldStyle;

  const SplashAnimatedBrandName({
    super.key,
    required this.main,
    required this.letterWidths,
    required this.letterOffsets,
    required this.fullCationWidth,
    required this.spaceWidth,
    required this.letterOpacities,
    required this.letterSlideX,
    required this.spaceOpacity,
    required this.finalTextScale,
    required this.boldStyle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      // ✅ يستمع لـ main فقط — pulse لا يؤثر هنا
      animation: main,
      builder: (context, _) {
        double cationWidth = 0;
        for (int i = 0; i < kSplashCationLetterCount; i++) {
          cationWidth +=
              letterOpacities[i].value.clamp(0.0, 1.0) * letterWidths[i];
        }
        cationWidth = cationWidth.clamp(0.0, fullCationWidth);

        final spaceVisible = (spaceOpacity.value * spaceWidth).clamp(
          0.0,
          spaceWidth,
        );

        return Semantics(
          label: 'EduZone', // check-ignore
          excludeSemantics: true,
          child: Transform.scale(
            scale: finalTextScale.value,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              textDirection: TextDirection.ltr,
              children: [
                Text('Edu', style: boldStyle), // check-ignore

                // "cation" — ينكمش مع انزلاق الأحرف
                ClipRect(
                  child: SizedBox(
                    width: cationWidth,
                    height: SplashConstants.letterHeight,
                    child: Stack(
                      children: List.generate(kSplashCationLetterCount, (i) {
                        return Positioned(
                          left: letterOffsets[i] + letterSlideX[i].value,
                          top: 0,
                          bottom: 0,
                          child: Opacity(
                            opacity: letterOpacities[i].value,
                            child: Center(
                              child: Text(kSplashCation[i], style: boldStyle),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),

                SizedBox(width: spaceVisible),
                Text('Zone', style: boldStyle), // check-ignore
              ],
            ),
          ),
        );
      },
    );
  }
}
