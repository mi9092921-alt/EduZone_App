import 'package:flutter/material.dart';

/// Large circular play button centered over the video when playback is
/// paused. Identical in fullscreen and non-fullscreen modes so the layout
/// doesn't shift when the user toggles fullscreen.
class OfflinePlayerCenterButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onPressed;

  const OfflinePlayerCenterButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        tooltip: tooltip,
        icon: const Icon(Icons.play_arrow_rounded),
        color: Colors.white,
        iconSize: 48,
        onPressed: onPressed,
      ),
    );
  }
}
