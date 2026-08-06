import 'package:flutter/material.dart';

import '../../../../../core/l10n/arb/app_localizations.dart';
import '../../../../../design_system/design_system.dart';

/// Center rewind / play-pause / fast-forward button row.
///
/// The play/pause button is decoupled from `media_kit`'s `Player` — it
/// depends only on a `Stream<bool>` of the playing state, so it can be
/// driven by a fake stream in tests.
class Player4CenterControls extends StatelessWidget {
  final bool isFullScreen;
  final Color primaryColor;
  final VoidCallback onRewind;
  final VoidCallback onFastForward;
  final Stream<bool> playingStream;
  final bool initialPlaying;
  final VoidCallback onTogglePlayback;

  const Player4CenterControls({
    super.key,
    required this.isFullScreen,
    required this.primaryColor,
    required this.onRewind,
    required this.onFastForward,
    required this.playingStream,
    required this.initialPlaying,
    required this.onTogglePlayback,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIconButton(
            icon: Icons.replay_10_rounded,
            color: Colors.white,
            iconSize: isFullScreen ? 28 : 32,
            semanticLabel: l10n.rewindButtonTooltip,
            onPressed: onRewind,
          ),
          const SizedBox(width: 32),
          StreamBuilder<bool>(
            stream: playingStream,
            initialData: initialPlaying,
            builder: (context, snapshot) {
              final isPlaying = snapshot.data ?? false;
              return CircleAvatar(
                radius: isFullScreen ? 26 : 30,
                backgroundColor: primaryColor,
                child: AppIconButton(
                  icon: isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  iconSize: isFullScreen ? 26 : 34,
                  semanticLabel: isPlaying
                      ? l10n.pauseButtonTooltip
                      : l10n.playButtonLabel,
                  onPressed: onTogglePlayback,
                ),
              );
            },
          ),
          const SizedBox(width: 32),
          AppIconButton(
            icon: Icons.forward_10_rounded,
            color: Colors.white,
            iconSize: isFullScreen ? 28 : 32,
            semanticLabel: l10n.fastForwardButtonTooltip,
            onPressed: onFastForward,
          ),
        ],
      ),
    );
  }
}
