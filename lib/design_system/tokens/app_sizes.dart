/// Standard sizes and dimensions for UI components across the app.
class AppSizes {
  AppSizes._();

  // Course Card specific sizes
  static const double courseCardWidth = 220.0;
  static const double courseCardCompactHeight = 100.0;
  static const double courseCardThumbnailWidth = 80.0;
  static const double courseCardThumbnailHeight = 60.0;

  // Icon sizes
  static const double iconXs = 12.0;
  static const double iconSm = 16.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 48.0;

  // Generic component sizes
  static const double buttonHeight = 48.0;
  static const double inputHeight = 56.0;
  static const double avatarSm = 32.0;
  static const double avatarMd = 48.0;
  static const double avatarLg = 64.0;

  // Progress indicators
  static const double progressHeight = 6.0;
  // Home "continue watching" carousel. The width is a cap, not a fixed
  // card width: the carousel uses the available viewport width on smaller
  // devices and stops growing on tablets/desktops.
  static const double resumeCardMaxWidth = 360.0;
  static const double resumeCardHeight = 208.0;
  static const double appBarHeight = 56.0;
  static const double bottomNavHeight = 64.0;
}
