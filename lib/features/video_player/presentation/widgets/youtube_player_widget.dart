import 'dart:math' as math;

import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/design_system/design_system.dart';
import 'package:app/shared/utils/player_ui_helpers.dart';
import 'package:app/shared/utils/video_duration_format.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class CustomYoutubePlayer extends StatefulWidget {
  final YoutubePlayerController controller;
  final bool showControls;
  final bool isVertical;
  final bool isFullScreen;
  final VoidCallback? onToggleFullScreen;

  const CustomYoutubePlayer({
    super.key,
    required this.controller,
    this.showControls = true,
    this.isVertical = false,
    this.isFullScreen = false,
    this.onToggleFullScreen,
  });

  @override
  State<CustomYoutubePlayer> createState() => _CustomYoutubePlayerState();
}

class _CustomYoutubePlayerState extends State<CustomYoutubePlayer> {
  bool _showOverlay = true;
  late final _hideControlsTimer = AutoHideControlsTimer(
    onHide: () {
      if (mounted && widget.controller.value.isPlaying) {
        setState(() {
          _showOverlay = false;
        });
      }
    },
  );

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideControlsTimer.dispose();
    super.dispose();
  }

  void _startHideTimer() {
    _hideControlsTimer.restart();
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });
    if (_showOverlay) {
      _startHideTimer();
    } else {
      _hideControlsTimer.cancel();
    }
  }

  void _seekRelative(int seconds) {
    final currentPosition = widget.controller.value.position;
    final targetPosition = currentPosition + Duration(seconds: seconds);
    widget.controller.seekTo(targetPosition);
    _startHideTimer();
  }

  void _togglePlayPause() {
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
      _hideControlsTimer.cancel();
      setState(() {
        _showOverlay = true;
      });
    } else {
      widget.controller.play();
      _startHideTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    // The package keeps its own aspect ratio from initState and does not
    // update it when this widget changes orientation. Give it tight external
    // bounds instead; this makes the app-owned orientation state authoritative
    // without recreating the YouTube controller or reloading the video.
    final player = SizedBox.expand(
      child: YoutubePlayer(
        controller: widget.controller,
        aspectRatio: widget.isVertical ? 9 / 16 : 16 / 9,
        onReady: () {
          _startHideTimer();
        },
      ),
    );

    final playerContent = Stack(
      alignment: Alignment.center,
      children: [
        player,
        if (widget.showControls)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleOverlay,
              behavior: HitTestBehavior.opaque,
              child: AnimatedOpacity(
                opacity: _showOverlay ? 1.0 : 0.0,
                duration: AppMotion.medium,
                // Do not keep rebuilding the complete controls tree on
                // every YouTube position tick while it is hidden.
                child: _showOverlay
                    ? ColoredBox(
                        color: Colors.black.withValues(alpha: 0.5),
                        child: AnimatedBuilder(
                          animation: widget.controller,
                          builder: (context, child) {
                            return widget.controller.value.isReady
                                ? _buildControls()
                                : const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  );
                          },
                        ),
                      )
                    : const SizedBox.expand(),
              ),
            ),
          ),
        if (widget.isFullScreen && widget.onToggleFullScreen != null)
          Positioned.directional(
            textDirection: Directionality.of(context),
            top: AppSpacing.sm,
            start: AppSpacing.sm,
            child: SafeArea(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: AppRadius.xsBorder,
                ),
                child: AppIconButton(
                  icon: Icons.fullscreen_exit_rounded,
                  color: Colors.white,
                  iconSize: 28,
                  semanticLabel: AppLocalizations.of(
                    context,
                  )!.exitFullScreenButtonTooltip,
                  onPressed: widget.onToggleFullScreen,
                ),
              ),
            ),
          ),
      ],
    );

    // Keep the same LayoutBuilder -> SizedBox -> playerContent hierarchy in
    // both modes. Switching the root widget type here would dispose the
    // package's YoutubePlayer subtree (and its platform WebView), which makes
    // YouTube load the video again from 0 when fullscreen is entered.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;

        if (widget.isFullScreen) {
          return SizedBox(
            width: width,
            height: maxHeight,
            child: playerContent,
          );
        }

        final naturalHeight = widget.isVertical
            ? width * 16 / 9
            : width * 9 / 16;
        // A 9:16 lesson is naturally taller than the remaining viewport on
        // many phones. Cap only the non-fullscreen surface so the sidebar's
        // Expanded child always receives usable height.
        final uncappedHeight = widget.isVertical
            ? math.min(naturalHeight, MediaQuery.sizeOf(context).height * 0.52)
            : naturalHeight;
        // The screen also gives the player a loose Flexible slot so the
        // lesson list always retains a valid finite remainder. Respect that
        // max height when the app bar/system insets leave less space than the
        // viewport-based vertical cap.
        final height = constraints.maxHeight.isFinite
            ? math.min(uncappedHeight, constraints.maxHeight)
            : uncappedHeight;

        return SizedBox(width: width, height: height, child: playerContent);
      },
    );
  }

  Widget _buildControls() {
    // Determine player states
    final isPlaying = widget.controller.value.isPlaying;

    return Stack(
      children: [
        // Center Controls
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIconButton(
                icon: Icons.replay_10_rounded,
                color: Colors.white,
                iconSize: 36,
                semanticLabel: AppLocalizations.of(
                  context,
                )!.rewindButtonTooltip,
                onPressed: _showOverlay ? () => _seekRelative(-10) : null,
              ),
              const SizedBox(width: AppSpacing.xl),
              AppIconButton(
                icon: isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_filled_rounded,
                color: Colors.white,
                iconSize: 72,
                semanticLabel: isPlaying
                    ? AppLocalizations.of(context)!.pauseButtonTooltip
                    : AppLocalizations.of(context)!.playButtonLabel,
                onPressed: _showOverlay ? _togglePlayPause : null,
              ),
              const SizedBox(width: AppSpacing.xl),
              AppIconButton(
                icon: Icons.forward_10_rounded,
                color: Colors.white,
                iconSize: 36,
                semanticLabel: AppLocalizations.of(
                  context,
                )!.fastForwardButtonTooltip,
                onPressed: _showOverlay ? () => _seekRelative(10) : null,
              ),
            ],
          ),
        ),
        // Bottom Controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_showOverlay)
                // isExpanded MUST stay false here. The package wraps an
                // expanded bar in an `Expanded`, which is a VERTICAL flex
                // inside this Column — and this Column is laid out by a
                // bottom-pinned Positioned child (left/right/bottom, no
                // top/height), so its incoming height is unbounded.
                // Flex + unbounded main axis = the
                // "RenderFlex children have non-zero flex but incoming
                // height constraints are unbounded" assertion. On device
                // (CPH2269, debug build, 2026-09-26) that failed layout
                // cascaded into an infinite
                // _RenderObjectSemantics._collectChildMergeUpAndSiblingGroup
                // recursion that wedged the main thread into an ANR while
                // entering fullscreen. The bar is already full-width via
                // the Positioned child's tight width (the package's
                // _buildBar uses BoxConstraints.expand), so no flex is
                // needed for the intended layout.
                ProgressBar(
                  controller: widget.controller,
                  colors: const ProgressBarColors(
                    playedColor: AppColors.primary,
                    handleColor: AppColors.primary,
                    backgroundColor: Colors.white30,
                    bufferedColor: Colors.white54,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Text(
                      formatVideoDurationPadded(
                        widget.controller.value.position,
                      ),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      ' / ',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      formatVideoDurationPadded(
                        widget.controller.metadata.duration,
                      ),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const Spacer(),
                    Theme(
                      data: Theme.of(context).copyWith(
                        iconTheme: const IconThemeData(color: Colors.white),
                        textTheme: TextTheme(
                          bodyMedium: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      child: Tooltip(
                        message: AppLocalizations.of(context)!.speedTooltip,
                        child: _CompactPlaybackSpeedButton(
                          controller: widget.controller,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A compact speed menu for the first (YouTube) player.
///
/// The package's [PlaybackSpeedButton] exposes eight fixed entries, which
/// makes the menu unnecessarily tall on mobile. Keep the common lecture
/// speeds here while preserving the controller's selected-rate check mark.
class _CompactPlaybackSpeedButton extends StatelessWidget {
  static final _speeds = <double, String>{
    2.0: '2.0x',
    1.5: '1.5x',
    1.25: '1.25x',
    1.0: 'Normal',
    0.5: '0.5x',
  };

  final YoutubePlayerController controller;

  const _CompactPlaybackSpeedButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      onSelected: controller.setPlaybackRate,
      itemBuilder: (context) => _speeds.entries
          .map(
            (entry) => CheckedPopupMenuItem<double>(
              value: entry.key,
              checked: controller.value.playbackRate == entry.key,
              child: Text(entry.value),
            ),
          )
          .toList(growable: false),
      child: const Padding(
        padding: EdgeInsetsDirectional.only(
          start: AppSpacing.sm,
          top: AppSpacing.sm,
          bottom: AppSpacing.sm,
        ),
        child: Icon(Icons.speed_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}
