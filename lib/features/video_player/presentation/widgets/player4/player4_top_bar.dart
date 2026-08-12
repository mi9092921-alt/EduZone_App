import 'package:flutter/material.dart';

import '../../../../../core/l10n/arb/app_localizations.dart';
import '../../../../../design_system/design_system.dart';
import '../../../data/models/streaming_video_info.dart';

/// Top control bar: fullscreen-exit button, mute toggle, playback-speed
/// menu, and quality menu.
///
/// Pure presentational widget — all state (current speed/quality/mute) and
/// the available options are passed in; every interaction is a callback.
class Player4TopBar extends StatelessWidget {
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

  final DesignSystemColors ds;

  const Player4TopBar({
    super.key,
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
    required this.ds,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        isFullScreen
            ? AppIconButton(
                icon: Icons.fullscreen_exit_rounded,
                color: Colors.white,
                iconSize: 24,
                semanticLabel: l10n.exitFullScreenButtonTooltip,
                onPressed: onExitFullScreen,
              )
            : const SizedBox(width: 40),
        Row(
          children: [
            // Mute/Unmute
            AppIconButton(
              icon: isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: Colors.white,
              iconSize: 22,
              semanticLabel: l10n.volumeTooltip,
              onPressed: onToggleMute,
            ),

            // Speed Menu
            PopupMenuButton<double>(
              icon: const Icon(Icons.speed_rounded, color: Colors.white, size: 22),
              tooltip: l10n.speedTooltip,
              color: ds.surface,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
              offset: const Offset(0, 35),
              constraints: const BoxConstraints(maxHeight: 240),
              onSelected: onSpeedSelected,
              itemBuilder: (context) => speeds
                  .map(
                    (s) => PopupMenuItem<double>(
                      value: s,
                      height: 36,
                      child: Text(
                        s == 1.0 ? l10n.normalSpeed : '${s}x',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: currentSpeed == s ? ds.primary : ds.textPrimary,
                          fontWeight: currentSpeed == s ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),

            // Quality Menu
            PopupMenuButton<StreamingFormat>(
              icon: const Icon(
                Icons.settings_suggest_rounded,
                color: Colors.white,
                size: 22,
              ),
              tooltip: l10n.settingsTooltip,
              color: ds.surface,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
              offset: const Offset(0, 35),
              onSelected: onQualitySelected,
              itemBuilder: (context) {
                final uniqueLabels = <String>{};
                final List<PopupMenuItem<StreamingFormat>> items = [];

                for (final targetLabel in targetQualities) {
                  final hasFormat = availableFormats.any(
                    (f) => f.quality.startsWith(targetLabel),
                  );
                  if (hasFormat && !uniqueLabels.contains(targetLabel)) {
                    uniqueLabels.add(targetLabel);
                    final formatData = availableFormats.firstWhere(
                      (f) => f.quality.startsWith(targetLabel),
                    );
                    final isSelected =
                        selectedFormat?.quality.startsWith(targetLabel) ?? false;

                    items.add(
                      PopupMenuItem<StreamingFormat>(
                        value: formatData,
                        height: 38,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (isSelected)
                              Icon(Icons.check_rounded, color: ds.primary, size: 16)
                            else
                              const SizedBox(width: 16),
                            Text(
                              targetLabel,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: isSelected ? ds.primary : ds.textPrimary,
                                fontWeight:
                                    isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                }
                return items;
              },
            ),
          ],
        ),
      ],
    );
  }
}
