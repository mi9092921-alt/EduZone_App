import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';

/// Floating fullscreen-exit button shown over the top-left corner of the
/// video while in fullscreen mode.
class ModernPlayerFullscreenExitButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onPressed;

  const ModernPlayerFullscreenExitButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: AppRadius.xsBorder,
      ),
      child: AppIconButton(
        icon: Icons.fullscreen_exit_rounded,
        color: Colors.white,
        iconSize: 28,
        semanticLabel: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
