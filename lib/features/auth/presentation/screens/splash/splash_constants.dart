import 'package:app/design_system/design_system.dart';

/// Layout/animation constants shared across the splash-screen sub-widgets.
///
/// Extracted from `splash_screen.dart` (previously a private `_K` class)
/// so the sub-widgets that now live in their own files
/// (`gradient_background.dart`, `animated_logo.dart`,
/// `animated_brand_name.dart`) can reference the same values without each
/// file redeclaring its own copy.
abstract final class SplashConstants {
  // Logo
  static const double logoSize = AppSpacing.xxxl; // 120
  // 32 — لا يوجد AppRadius بقيمة 32، فاستُخدم رمز AppSpacing بنفس القيمة
  static const double logoRadius = AppSpacing.xl2;
  static const double logoIconSize = 60; // no matching design token (v1)
  static const double logoTranslateY = AppSpacing.xl12; // 96 px عند بداية الانزلاق

  // Brand text
  // 30 — بين h1 (28) و display (36): no matching design token (v1)
  static const double fontSize = 30;
  // مرتبط بـ fontSize + letterSpacing — no matching design token (v1)
  static const double letterHeight = 42;

  // Parallax
  // 10 — القيمة مطابقة لرمز AppSpacing.alias وليست دلاليًا مسافة زر
  static const double parallaxRange = AppSpacing.buttonPaddingV;
}

/// "cation" — الجزء المتحرك من "Education" الذي ينزلق حرفًا حرفًا.
/// ثابت مشترك بين [splash_screen.dart] (القياس) والرسم في
/// `animated_brand_name.dart` حتى لا يُعدَّل أحدهما دون الآخر لو تغيّرت
/// الكلمة مستقبلًا (Rebrand مثلًا).
const String kSplashCation = 'cation';
const int kSplashCationLetterCount = 6;
