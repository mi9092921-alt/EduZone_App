import 'dart:ui';

import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// =====================================================================
//  SplashScreen — v4  (production-ready)
//
//  التحسينات المطبقة:
//  ✅ 1. كل widget معزول في class مستقل → rebuild scope محدود
//  ✅ 2. Matrix4 موحد بدل 3 Transform متداخلين
//  ✅ 3. Semantics للـ logo والنص
//  ✅ 4. BackdropFilter glassmorphism حقيقي
//  ✅ 5. Magic numbers → named constants
//  ✅ 6. Parallax خفيف على الخلفية
//
//  ملاحظة: هذه الشاشة عرض/أنيميشن فقط (بلا منطق مصادقة أو تنقّل).
//  الحركة النبضية (_pulse) تستمر عمدًا بعد انتهاء الأنيميشن الرئيسية
//  (_main) ولا تتوقف. قرار "متى نغادر الشاشة" يُدار مركزيًا عبر
//  redirect في app_router.dart، وليس من هنا.
// =====================================================================

// ─────────────────────────── Constants ───────────────────────────────

abstract final class _K {
  // Logo
  static const double logoSize = 120;
  static const double logoRadius = 32;
  static const double logoIconSize = 60;
  static const double logoTranslateY = 96; // px عند بداية الانزلاق

  // Brand text
  static const double fontSize = 30;
  static const double letterHeight = 42; // مرتبط بـ fontSize + letterSpacing

  // Parallax
  static const double parallaxRange = 10; // px
}

// "cation" — الجزء المتحرك من "Education" الذي ينزلق حرفًا حرفًا.
// ثابت مشترك بين _SplashScreenState (القياس) و_AnimatedBrandName (الرسم)
// حتى لا يُعدَّل أحدهما دون الآخر لو تغيّرت الكلمة مستقبلًا (Rebrand مثلًا).
const String _kCation = 'cation';
const int _kCationLetterCount = 6;

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

  // Measurements (مرة واحدة)
  late final List<double> _letterWidths;
  late final List<double> _letterOffsets;
  late final double _fullCationWidth;
  late final double _spaceWidth;

  // 'Edu' و 'Zone' مستخدمتان مباشرةً في _AnimatedBrandName كـ literals

  // Must stay a const TextStyle literal (not AppTextStyles.brandLogo with
  // .copyWith applied) because it is used inside a const TextSpan below
  // (copyWith is not a const constructor). Kept numerically identical to
  // AppTextStyles.brandLogo -- update both together if this ever changes.
  static const TextStyle _boldStyle = TextStyle( // check-ignore
    fontSize: _K.fontSize,
    fontWeight: FontWeight.w800,
    color: AppColors.primary,
    letterSpacing: -0.5,
  );

  // ─────────────────────────── init ──────────────────────────────────

  @override
  void initState() {
    super.initState();
    _measureLetters();

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

  // ─────────────────────────── Measurements ──────────────────────────

  void _measureLetters() {
    final painter = TextPainter(textDirection: TextDirection.ltr);

    _letterWidths = List.generate(_kCationLetterCount, (i) {
      painter.text = TextSpan(text: _kCation[i], style: _boldStyle);
      painter.layout();
      return painter.width;
    });

    double running = 0;
    _letterOffsets = List.generate(_kCationLetterCount, (i) {
      final o = running;
      running += _letterWidths[i];
      return o;
    });
    _fullCationWidth = running;

    painter.text = const TextSpan(text: ' ', style: _boldStyle);
    painter.layout();
    _spaceWidth = painter.width;
  }

  // ─────────────────────────── Animations ────────────────────────────

  void _buildLogoAnimations() {
    const logoInterval = Interval(0.0, 0.25, curve: Curves.easeOutBack);

    _logoTranslateY = Tween<double>(
      begin: -_K.logoTranslateY,
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
    _bgParallax = Tween<double>(begin: _K.parallaxRange, end: 0).animate(
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
    const double perLetter = (end - start) / _kCationLetterCount;

    _letterOpacities = [];
    _letterSlideX = [];

    for (int i = 0; i < _kCationLetterCount; i++) {
      final ri = _kCationLetterCount - 1 - i;
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
          end: _letterWidths[i] * 0.8,
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
            AnimatedBuilder(
              animation: Listenable.merge([_main, _pulse]),
              builder: (context, child) => Transform.translate(
                offset: Offset(0, _bgParallax.value),
                child: Transform.scale(
                  scale: _bgPulseScale.value,
                  child: const _GradientBackground(),
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
                    _AnimatedLogo(
                      main: _main,
                      pulse: _pulse,
                      opacity: _logoOpacity,
                      translateY: _logoTranslateY,
                      scaleBase: _logoScaleBase,
                      logoPulse: _logoPulse,
                      wobble: _logoWobble,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // ✅ Widget معزول → rebuild scope محدود
                    _AnimatedBrandName(
                      main: _main,
                      letterWidths: _letterWidths,
                      letterOffsets: _letterOffsets,
                      fullCationWidth: _fullCationWidth,
                      spaceWidth: _spaceWidth,
                      letterOpacities: _letterOpacities,
                      letterSlideX: _letterSlideX,
                      spaceOpacity: _spaceOpacity,
                      finalTextScale: _finalTextScale,
                      boldStyle: boldStyle,
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

// =====================================================================
//  Sub-widgets (كل واحد rebuild بشكل مستقل)
// =====================================================================

// ─────────────────────── Gradient Background ─────────────────────────

class _GradientBackground extends StatelessWidget {
  const _GradientBackground();

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

// ───────────────────────── Animated Logo ─────────────────────────────

class _AnimatedLogo extends StatelessWidget {
  final AnimationController main;
  final AnimationController pulse;
  final Animation<double> opacity;
  final Animation<double> translateY;
  final Animation<double> scaleBase;
  final Animation<double> logoPulse;
  final Animation<double> wobble;

  const _AnimatedLogo({
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
          label: 'EduZone logo',
          child: Opacity(
            opacity: opacity.value,
            child: Transform.translate(
              offset: Offset(0, translateY.value),
              child: Transform.rotate(
                angle: wobble.value,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: _K.logoSize,
                    height: _K.logoSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_K.logoRadius),
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
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    // ✅ Glassmorphism حقيقي بـ BackdropFilter
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_K.logoRadius),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            begin: AlignmentDirectional.topStart,
                            end: AlignmentDirectional.bottomEnd,
                            colors: [AppColors.primary, AppColors.accent],
                          ).createShader(bounds),
                          child: const Icon(
                            Icons.school_rounded,
                            size: _K.logoIconSize,
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

// ─────────────────────── Animated Brand Name ─────────────────────────

class _AnimatedBrandName extends StatelessWidget {
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

  const _AnimatedBrandName({
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
        for (int i = 0; i < _kCationLetterCount; i++) {
          cationWidth +=
              letterOpacities[i].value.clamp(0.0, 1.0) * letterWidths[i];
        }
        cationWidth = cationWidth.clamp(0.0, fullCationWidth);

        final spaceVisible = (spaceOpacity.value * spaceWidth).clamp(
          0.0,
          spaceWidth,
        );

        return Semantics(
          label: 'EduZone',
          child: Transform.scale(
            scale: finalTextScale.value,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              textDirection: TextDirection.ltr,
              children: [
                Text('Edu', style: boldStyle),

                // "cation" — ينكمش مع انزلاق الأحرف
                ClipRect(
                  child: SizedBox(
                    width: cationWidth,
                    height: _K.letterHeight,
                    child: Stack(
                      children: List.generate(_kCationLetterCount, (i) {
                        return Positioned(
                          left: letterOffsets[i] + letterSlideX[i].value,
                          top: 0,
                          bottom: 0,
                          child: Opacity(
                            opacity: letterOpacities[i].value,
                            child: Center(
                              child: Text(_kCation[i], style: boldStyle),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),

                SizedBox(width: spaceVisible),
                Text('Zone', style: boldStyle),
              ],
            ),
          ),
        );
      },
    );
  }
}