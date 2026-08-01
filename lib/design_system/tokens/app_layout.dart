/// Standard layout constraints, aspect ratios, and grid configurations.
class AppLayout {
  AppLayout._();

  // Aspect Ratios
  static const double cardAspectRatio = 16 / 9;
  static const double thumbnailAspectRatio = 4 / 3;
  static const double videoAspectRatio = 16 / 9;
  static const double squareAspectRatio = 1 / 1;

  // Grid Constraints
  static const int gridColumnsMobile = 2;
  static const int gridColumnsTablet = 3;
  static const int gridColumnsDesktop = 4;

  // Scaling factors
  static const double dprAwareScale =
      2.0; // Target over-sampling for disk cache

  // Content Widths
  static const double maxContentWidth = 1200.0;
  static const double sidebarWidth = 260.0;
  static const double modalMaxWidth = 500.0;
}
