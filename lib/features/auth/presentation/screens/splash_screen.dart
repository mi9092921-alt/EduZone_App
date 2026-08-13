import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'splash/animated_brand_name.dart';
import 'splash/animated_logo.dart';
import 'splash/gradient_background.dart';
import 'splash/splash_brand_metrics.dart';
import 'splash/splash_constants.dart';

// =====================================================================
//  SplashScreen — v4  (production-ready)
//
//  التحسينات المطبقة:
//  ✅ 1. كل widget معزول في class مستقل → rebuild scope محدود
//     (الآن كل واحد في ملفه الخاص تحت screens/splash/)
//  ✅ 2. Matrix4 موحد بدل 3 Transform متداخلين
//  ✅ 3. Semantics للـ logo والنص
//  ✅ 4. BackdropFilter glassmorphism حقيقي
//  ✅ 5. Magic numbers → named constants (splash/splash_constants.dart)
//  ✅ 6. Parallax خفيف على الخلفية
//
//  ملاحظة: هذه الشاشة عرض/أنيميشن فقط (بلا منطق مصادقة أو تنقّل).
//  الحركة النبضية (_pulse) تستمر عمدًا بعد انتهاء الأنيميشن الرئيسية
//  (_main) ولا تتوقف. قرار "متى نغادر الشاشة" يُدار مركزيًا عبر
//  redirect في app_router.dart، وليس من هنا.
//
//  البنية بعد التقسيم:
//   - splash_screen.dart          → هذا الملف: التحكّم بالأنيميشن + build()
//   - splash/splash_constants.dart → الثوابت المشتركة
//   - splash/splash_brand_metrics.dart → قياس الحروف (منطق صرف، قابل للاختبار)
//   - splash/gradient_background.dart  → خلفية التدرّج
//   - splash/animated_logo.dart        → اللوغو المتحرك
//   - splash/animated_brand_name.dart  → اسم العلامة المتحرك
// =====================================================================

// ─────────────────────────── Entry point ─────────────────────────────
//
//  الاستخدام في app_router.dart:
//
//    SplashScreen(nextScreen: (_) => const HomeScreen())
//
//  أو مع GoRouter:
//
//    GoRoute(
//      path: '/',
//      builder: (context, state) => SplashScreen(
//        nextScreen: (_) => const HomeScreen(),
//      ),
//    )

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Controllers
  late final AnimationController _main;
  late final AnimationController _pulse;

  // Logo
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScaleBase;
  late final Animation<double> _logoPulse;
  late final Animation<double> _logoWobble;
  late final Animation<double> _logoTranslateY;

  // Background parallax and pulse
  late final Animation<double> _bgParallax;
  late final Animation<double> _bgPulseScale;

  // Brand text
  late final List<Animation<double>> _letterOpacities;
  late final List<Animation<double>> _letterSlideX; // بالـ px
  late final Animation<double> _spaceOpacity;
  late final Animation<double> _finalTextScale;

  // Measurements (مرة واحدة) — انظر splash/splash_brand_metrics.dart
  late final SplashBrandMetrics _brandMetrics;

  // 'Edu' و 'Zone' مستخدمتان مباشرةً في SplashAnimatedBrandName كـ literals

  // Must stay a const TextStyle literal (not AppTextStyles.brandLogo with
  // .copyWith applied) because it is used for measurement via TextPainter
  // below (copyWith is not a const constructor). Kept numerically
  // identical to AppTextStyles.brandLogo -- update both together if this
  // ever changes.
  static const TextStyle _boldStyle = TextStyle( // check-ignore
    fontSize: SplashConstants.fontSize,
    fontWeight: FontWeight.w800,
    color: AppColors.primary,
    letterSpacing: -0.5,
  );

  // ─────────────────────────── init ──────────────────────────────────

  @override
  void initState() {
    super.initState();
    _brandMetrics = SplashBrandMetrics.measure(_boldStyle);

    _main = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _buildLogoAnimations();
    _buildTextAnimations();

    _main.forward();
  }

  // ─────────────────────────── Animations ────────────────────────────

  void _buildLogoAnimations() {
    const logoInterval = Interval(0.0, 0.25, curve: Curves.easeOutBack);

    _logoTranslateY = Tween<double>(
      begin: -SplashConstants.logoTranslateY,
      end: 0,
    ).animate(CurvedAnimation(parent: _main, curve: logoInterval));

    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _main,
        curve: const Interval(0.0, 0.25, curve: Curves.easeIn),
      ),
    );

    _logoScaleBase = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _main, curve: logoInterval));

    _logoPulse = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    _logoWobble =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.05), weight: 34),
          TweenSequenceItem(tween: Tween(begin: 0.05, end: -0.05), weight: 33),
          TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.0), weight: 33),
        ]).animate(
          CurvedAnimation(
            parent: _main,
            curve: const Interval(0.1, 0.35, curve: Curves.easeInOut),
          ),
        );

    // ✅ Parallax خفيف: الخلفية تتحرك بعكس اللوغو بمقدار أقل
    _bgParallax = Tween<double>(begin: SplashConstants.parallaxRange, end: 0)
        .animate(
          CurvedAnimation(
            parent: _main,
            curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
          ),
        );

    // ✅ حركة نبضية خفيفة جداً للخلفية
    _bgPulseScale = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  void _buildTextAnimations() {
    const double start = 0.3;
    const double end = 0.8;
    const double perLetter = (end - start) / kSplashCationLetterCount;

    _letterOpacities = [];
    _letterSlideX = [];

    for (int i = 0; i < kSplashCationLetterCount; i++) {
      final ri = kSplashCationLetterCount - 1 - i;
      final ls = start + ri * perLetter;
      final le = ls + perLetter;
      final curve = Interval(ls, le, curve: Curves.easeIn);

      _letterOpacities.add(
        Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).animate(CurvedAnimation(parent: _main, curve: curve)),
      );

      // ✅ الانزلاق نسبي لعرض الحرف → لا يتجاوز ClipRect
      _letterSlideX.add(
        Tween<double>(
          begin: 0,
          end: _brandMetrics.letterWidths[i] * 0.8,
        ).animate(CurvedAnimation(parent: _main, curve: curve)),
      );
    }

    _spaceOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _main,
        curve: const Interval(0.85, 0.95, curve: Curves.easeIn),
      ),
    );

    _finalTextScale =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.06), weight: 70),
          TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 30),
        ]).animate(
          CurvedAnimation(
            parent: _main,
            curve: const Interval(0.95, 1.0, curve: Curves.easeInOut),
          ),
        );
  }

  // ─────────────────────────── dispose ───────────────────────────────

  @override
  void dispose() {
    _main.dispose();
    _pulse.dispose();
    super.dispose();
  }

  // ─────────────────────────── build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boldStyle = AppTextStyles.brandLogo.copyWith(
      color: isDark ? Colors.white : AppColors.primary,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ✅ Parallax and Pulse background
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([_main, _pulse]),
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _bgParallax.value),
                  child: Transform.scale(
                    scale: _bgPulseScale.value,
                    child: const SplashGradientBackground(),
                  ),
                ),
              ),
            ),

            // Content
            AppScreen(
              scrollable: false,
              useScaffold: false,
              backgroundColor: Colors.transparent,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✅ Widget معزول → rebuild scope محدود
                    RepaintBoundary(
                      child: SplashAnimatedLogo(
                        main: _main,
                        pulse: _pulse,
                        opacity: _logoOpacity,
                        translateY: _logoTranslateY,
                        scaleBase: _logoScaleBase,
                        logoPulse: _logoPulse,
                        wobble: _logoWobble,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // ✅ Widget معزول → rebuild scope محدود
                    RepaintBoundary(
                      child: SplashAnimatedBrandName(
                        main: _main,
                        letterWidths: _brandMetrics.letterWidths,
                        letterOffsets: _brandMetrics.letterOffsets,
                        fullCationWidth: _brandMetrics.fullCationWidth,
                        spaceWidth: _brandMetrics.spaceWidth,
                        letterOpacities: _letterOpacities,
                        letterSlideX: _letterSlideX,
                        spaceOpacity: _spaceOpacity,
                        finalTextScale: _finalTextScale,
                        boldStyle: boldStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
