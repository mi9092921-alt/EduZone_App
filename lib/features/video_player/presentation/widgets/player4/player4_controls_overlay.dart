import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import '../../../data/models/streaming_video_info.dart';
import 'player4_center_controls.dart';
import 'player4_seek_bar.dart';
import 'player4_top_bar.dart';

/// Full controls overlay: dim background + top bar + center playback
/// controls + bottom seek bar, with tap-to-show/hide behavior.
///
/// The caller is responsible for not rendering this at all while loading
/// or in an error state (mirrors the original's
/// `if (_isLoadingVideoData || _hasError) return const SizedBox.shrink();`
/// guard, which is a decision about *whether* to show controls, not part
/// of the overlay's own rendering).
class Player4ControlsOverlay extends StatelessWidget {
  final bool showControls;
  final VoidCallback onToggleControls;

  final bool isFullScreen;
  final VoidCallback onExitFullScreen;

  final bool isMuted;
  final VoidCallback onToggleMute;

  final List<double> speeds;
  final double currentSpeed;
  final ValueChanged<double> onSpeedSelected;

  final List<String> targetQualities;
  final List<StreamingFormat> availableFormats;
  final StreamingFormat? selectedFormat;
  final ValueChanged<StreamingFormat> onQualitySelected;

  final VoidCallback onRewind;
  final VoidCallback onFastForward;
  final Stream<bool> playingStream;
  final bool initialPlaying;
  final VoidCallback onTogglePlayback;

  final Stream<Duration> positionStream;
  final Duration initialPosition;
  final Stream<Duration> durationStream;
  final Duration initialDuration;
  final ValueChanged<Duration> onSeek;

  final DesignSystemColors ds;

  const Player4ControlsOverlay({
    super.key,
    required this.showControls,
    required this.onToggleControls,
    required this.isFullScreen,
    required this.onExitFullScreen,
    required this.isMuted,
    required this.onToggleMute,
    required this.speeds,
    required this.currentSpeed,
    required this.onSpeedSelected,
    required this.targetQualities,
    required this.availableFormats,
    required this.selectedFormat,
    required this.onQualitySelected,
    required this.onRewind,
    required this.onFastForward,
    required this.playingStream,
    required this.initialPlaying,
    required this.onTogglePlayback,
    required this.positionStream,
    required this.initialPosition,
    required this.durationStream,
    required this.initialDuration,
    required this.onSeek,
    required this.ds,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onToggleControls,
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          opacity: showControls ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !showControls,
            child: Stack(
              children: [
                // Semi-transparent background
                Container(color: Colors.black.withValues(alpha: 0.45)),

                // Top control bar
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  child: Player4TopBar(
                    isFullScreen: isFullScreen,
                    onExitFullScreen: onExitFullScreen,
                    isMuted: isMuted,
                    onToggleMute: onToggleMute,
                    speeds: speeds,
                    currentSpeed: currentSpeed,
                    onSpeedSelected: onSpeedSelected,
                    targetQualities: targetQualities,
                    availableFormats: availableFormats,
                    selectedFormat: selectedFormat,
                    onQualitySelected: onQualitySelected,
                    ds: ds,
                  ),
                ),

                // Center playback buttons
                Player4CenterControls(
                  isFullScreen: isFullScreen,
                  primaryColor: ds.primary,
                  onRewind: onRewind,
                  onFastForward: onFastForward,
                  playingStream: playingStream,
                  initialPlaying: initialPlaying,
                  onTogglePlayback: onTogglePlayback,
                ),

                // Bottom time bar & Slider
                Positioned(
                  bottom: isFullScreen ? AppSpacing.md : AppSpacing.xs,
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  child: Player4SeekBar(
                    positionStream: positionStream,
                    initialPosition: initialPosition,
                    durationStream: durationStream,
                    initialDuration: initialDuration,
                    ds: ds,
                    onSeek: onSeek,
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
