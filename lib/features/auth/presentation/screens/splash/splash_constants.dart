/// Layout/animation constants shared across the splash-screen sub-widgets.
///
/// Extracted from `splash_screen.dart` (previously a private `_K` class)
/// so the sub-widgets that now live in their own files
/// (`gradient_background.dart`, `animated_logo.dart`,
/// `animated_brand_name.dart`) can reference the same values without each
/// file redeclaring its own copy.
abstract final class SplashConstants {
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

/// "cation" — الجزء المتحرك من "Education" الذي ينزلق حرفًا حرفًا.
/// ثابت مشترك بين [splash_screen.dart] (القياس) والرسم في
/// `animated_brand_name.dart` حتى لا يُعدَّل أحدهما دون الآخر لو تغيّرت
/// الكلمة مستقبلًا (Rebrand مثلًا).
const String kSplashCation = 'cation';
const int kSplashCationLetterCount = 6;
