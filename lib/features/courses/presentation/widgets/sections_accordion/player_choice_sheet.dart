import 'package:flutter/material.dart';

import '../../../../../core/l10n/arb/app_localizations.dart';
import '../../../../../design_system/design_system.dart';
import 'player_option_tile.dart';

/// Opens the "choose a player" bottom sheet with the three available player
/// implementations. [onPlayerSelected] is called with `'youtube'`,
/// `'modern'`, or `'player4'` once the user picks one.
///
/// [showDirectPlayer] is the remote kill switch for the direct (player4)
/// option — `FeatureFlagKey.playerDirectPlayer` (default `true`, i.e.
/// current behavior). When `false` the option is omitted entirely and the
/// user chooses between the remaining players; nothing else changes.
Future<void> showPlayerChoiceSheet(
  BuildContext context, {
  required ValueChanged<String> onPlayerSelected,
  bool showDirectPlayer = true,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => PlayerChoiceSheet(
      onPlayerSelected: onPlayerSelected,
      showDirectPlayer: showDirectPlayer,
    ),
  );
}

/// Content of the "choose a player" bottom sheet.
///
/// NOTE (preserved as-is, not part of this refactor): unlike the
/// `directPlayer`/`directPlayerSubtitle` entry (which is localized), the
/// other three entries' titles/subtitles are hardcoded Arabic/English
/// strings rather than going through `AppLocalizations`. Flagging this as
/// a pre-existing inconsistency rather than silently localizing it, since
/// that would be a behavior change beyond a pure structural split.
class PlayerChoiceSheet extends StatelessWidget {
  final ValueChanged<String> onPlayerSelected;

  /// Remote kill switch for the direct (player4) option — see
  /// [showPlayerChoiceSheet]. Defaults to true (current behavior) so the
  /// sheet is also safe to construct outside the flag-wired call site.
  final bool showDirectPlayer;

  const PlayerChoiceSheet({
    super.key,
    required this.onPlayerSelected,
    this.showDirectPlayer = true,
  });

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ds.textMuted.withValues(alpha: 0.2),
                borderRadius: AppRadius.hairlineBorder,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              l10n.choosePlayer,
              style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.lg),
            PlayerOptionTile(
              title: l10n.youtubePlayer,
              subtitle: l10n.youtubePlayerSubtitle,
              icon: Icons.smart_display_rounded,
              onTap: () => onPlayerSelected('youtube'),
            ),
            const SizedBox(height: AppSpacing.md),
            PlayerOptionTile(
              title: l10n.modernPlayer,
              subtitle: l10n.modernPlayerSubtitle,
              icon: Icons.auto_awesome_rounded,
              onTap: () => onPlayerSelected('modern'),
            ),
            // Feature-flag kill switch (FeatureFlagKey.playerDirectPlayer):
            // when the flag is disabled the direct player is not offered,
            // but the sheet and the remaining players stay fully usable.
            if (showDirectPlayer) ...[
              const SizedBox(height: AppSpacing.md),
              PlayerOptionTile(
                title: l10n.directPlayer,
                subtitle: l10n.directPlayerSubtitle,
                icon: Icons.play_circle_outline_rounded,
                onTap: () => onPlayerSelected('player4'),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
