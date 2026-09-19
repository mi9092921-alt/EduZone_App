/// Responsive-layout policy values.
///
/// The app is deliberately mobile-first: [AdaptiveValue.maxContentWidth]
/// caps main content width on tablet/desktop and centers it (see
/// `lib/app/router/main_shell.dart`) while the bottom navigation stays on
/// every screen size. A breakpoint-switching widget (mobile/tablet/desktop
/// builders over `core/layout/breakpoints.dart`) previously lived here but
/// had zero call sites — it was removed rather than kept as dead API; if a
/// screen ever genuinely needs per-breakpoint layouts, reintroduce the
/// switcher alongside a real consumer.
abstract final class AdaptiveValue {
  /// Maximum width for main content areas on tablet/desktop, so lists and
  /// cards don't stretch edge-to-edge on wide windows.
  static const double maxContentWidth = 840;
}
