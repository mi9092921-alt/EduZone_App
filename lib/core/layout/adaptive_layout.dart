import 'package:flutter/material.dart';

import 'breakpoints.dart';

/// Responsive layout switcher over [Breakpoints].
///
/// Builds one of three layouts depending on the available width:
/// mobile (<600px), tablet (600–1200px), desktop (≥1200px).
class AdaptiveLayout extends StatelessWidget {
  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  const AdaptiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width < Breakpoints.mobile) {
          return mobile(context);
        }
        if (width >= Breakpoints.desktop && desktop != null) {
          return desktop!(context);
        }
        if (width >= Breakpoints.mobile && tablet != null) {
          return tablet!(context);
        }
        // Desktop/tablet without a matching builder falls back gracefully.
        return (tablet ?? mobile)(context);
      },
    );
  }
}

/// Responsive value helpers over [Breakpoints].
abstract final class AdaptiveValue {
  /// Maximum width for main content areas on tablet/desktop, so lists and
  /// cards don't stretch edge-to-edge on wide windows.
  static const double maxContentWidth = 840;
}
