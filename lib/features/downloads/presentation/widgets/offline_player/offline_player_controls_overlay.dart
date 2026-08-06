import 'package:flutter/material.dart';

import '../../../../../core/l10n/arb/app_localizations.dart';
import '../../../../../design_system/design_system.dart';

/// Bottom control bar (seek slider + play/pause/rewind/speed/fullscreen)
/// with tap-to-show/hide behavior.
///
/// The seek slider is passed in as [seekSlider] (composition) rather than
/// built internally, so this widget stays decoupled from `media_kit`'s
/// `Player` and is fully unit-testable with a placeholder in its place.
class OfflinePlayerControlsOverlay extends StatelessWidget {
  final bool showControls;
  final VoidCallback onToggleControls;
  final Widget seekSlider;
  final bool isPlaying;
  final VoidCallback onTogglePlayback;
  final VoidCallback onRewind;
  final VoidCallback onFastForward;
  final String speedLabel;
  final VoidCallback onCycleSpeed;
  final bool isFullScreen;
  final VoidCallback onFullscreenToggle;

  const OfflinePlayerControlsOverlay({
    super.key,
    required this.showControls,
    required this.onToggleControls,
    required this.seekSlider,
    required this.isPlaying,
    required this.onTogglePlayback,
    required this.onRewind,
    required this.onFastForward,
    required this.speedLabel,
    required this.onCycleSpeed,
    required this.isFullScreen,
    required this.onFullscreenToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // GestureDetector sits OUTSIDE IgnorePointer so taps always reach it
    // regardless of whether controls are visible. IgnorePointer only blocks
    // the inner buttons/slider when hidden — not the tap-to-show gesture.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggleControls,
      child: IgnorePointer(
        ignoring: !showControls,
        child: AnimatedOpacity(
          opacity: showControls ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: ColoredBox(
            color: Colors.transparent,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: seekSlider,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: isPlaying
                            ? l10n.pauseButtonTooltip
                            : l10n.playButtonLabel,
                        onPressed: onTogglePlayback,
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.rewindButtonTooltip,
                        onPressed: onRewind,
                        icon: const Icon(
                          Icons.replay_10,
                          color: Colors.white,
                        ),
                      ),
                      TextButton(
                        onPressed: onCycleSpeed,
                        child: Text(
                          speedLabel,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.fastForwardButtonTooltip,
                        onPressed: onFastForward,
                        icon: const Icon(
                          Icons.forward_10,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        tooltip: isFullScreen
                            ? l10n.exitFullScreenButtonTooltip
                            : l10n.fullScreenButtonTooltip,
                        onPressed: onFullscreenToggle,
                        icon: Icon(
                          isFullScreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
