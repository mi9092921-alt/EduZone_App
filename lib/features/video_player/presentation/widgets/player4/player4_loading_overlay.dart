import 'package:flutter/material.dart';

/// Full-bleed loading overlay shown while video data is being fetched.
///
/// The original inlined two near-identical copies of this — one with
/// `Colors.black.withValues(alpha: 0.8)` for fullscreen, one with
/// `Colors.black54` for non-fullscreen. Parameterized here as
/// [backgroundColor] instead of duplicated, with each call site passing
/// its original color so on-screen behavior is unchanged.
class Player4LoadingOverlay extends StatelessWidget {
  final Color backgroundColor;
  final Color spinnerColor;

  const Player4LoadingOverlay({
    super.key,
    required this.backgroundColor,
    required this.spinnerColor,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: Center(child: CircularProgressIndicator(color: spinnerColor)),
    );
  }
}
