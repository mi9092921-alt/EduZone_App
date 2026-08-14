import 'dart:async';

import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class CustomYoutubePlayer extends StatefulWidget {
  final YoutubePlayerController controller;
  final bool showControls;
  final bool isVertical;

  const CustomYoutubePlayer({
    super.key,
    required this.controller,
    this.showControls = true,
    this.isVertical = false,
  });

  @override
  State<CustomYoutubePlayer> createState() => _CustomYoutubePlayerState();
}

class _CustomYoutubePlayerState extends State<CustomYoutubePlayer> {
  bool _showOverlay = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.controller.value.isPlaying) {
        setState(() {
          _showOverlay = false;
        });
      }
    });
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });
    if (_showOverlay) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
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
      _hideTimer?.cancel();
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
    final player = YoutubePlayer(
      controller: widget.controller,
      aspectRatio: widget.isVertical ? 9 / 16 : 16 / 9,
      onReady: () {
        _startHideTimer();
      },
    );

    return Stack(
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
                child: ColoredBox(
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
                ),
              ),
            ),
          ),
      ],
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
                semanticLabel: AppLocalizations.of(context)!.rewindButtonTooltip,
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
                semanticLabel: AppLocalizations.of(context)!.fastForwardButtonTooltip,
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
                ProgressBar(
                  isExpanded: true,
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
                      _formatDuration(widget.controller.value.position),
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
                      _formatDuration(widget.controller.metadata.duration),
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
                        child: PlaybackSpeedButton(
                          controller: widget.controller,
                          icon: const Icon(
                            Icons.speed_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds';
    } else {
      return '$twoDigitMinutes:$twoDigitSeconds';
    }
  }
}
