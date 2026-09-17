import 'package:flutter/material.dart';

import '../../../../../core/l10n/arb/app_localizations.dart';
import '../../../../../design_system/design_system.dart';
import 'player_option_tile.dart';

/// Opens the "choose a player" bottom sheet with the available player
/// implementations. [onPlayerSelected] is called with `'youtube'`,
/// `'modern'`, or `'player4'` once the user picks one.
///
/// The three `show...` parameters are remote kill switches wired from
/// [FeatureFlagKey] (`playerYoutube` / `playerModern` /
/// `playerDirectPlayer`, default `true`, i.e. current behavior). When one
/// is `false` the corresponding option is omitted entirely and the user
/// chooses between the remaining players; nothing else changes. When every
/// option is hidden the sheet is not opened at all — the lesson tap stays
/// a no-op instead of presenting an empty sheet.
Future<void> showPlayerChoiceSheet(
  BuildContext context, {
  required ValueChanged<String> onPlayerSelected,
  bool showYoutube = true,
  bool showModern = true,
  bool showDirectPlayer = true,
}) {
  if (!(showYoutube || showModern || showDirectPlayer)) {
    return Future.value();
  }
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => PlayerChoiceSheet(
      onPlayerSelected: onPlayerSelected,
      showYoutube: showYoutube,
      showModern: showModern,
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

  /// Remote kill switches for the youtube / modern / direct (player4)
  /// options — see [showPlayerChoiceSheet]. Each defaults to true (current
  /// behavior) so the sheet is also safe to construct outside the
  /// flag-wired call site.
  final bool showYoutube;
  final bool showModern;
  final bool showDirectPlayer;

  const PlayerChoiceSheet({
    super.key,
    required this.onPlayerSelected,
    this.showYoutube = true,
    this.showModern = true,
    this.showDirectPlayer = true,
  });

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // Feature-flag kill switches (FeatureFlagKey.playerYoutube /
    // playerModern / playerDirectPlayer): a disabled player is not offered,
    // but the sheet and the remaining players stay fully usable.
    final options = <Widget>[
      if (showYoutube)
        PlayerOptionTile(
          title: l10n.youtubePlayer,
          subtitle: l10n.youtubePlayerSubtitle,
          icon: Icons.smart_display_rounded,
          onTap: () => onPlayerSelected('youtube'),
        ),
      if (showModern)
        PlayerOptionTile(
          title: l10n.modernPlayer,
          subtitle: l10n.modernPlayerSubtitle,
          icon: Icons.auto_awesome_rounded,
          onTap: () => onPlayerSelected('modern'),
        ),
      if (showDirectPlayer)
        PlayerOptionTile(
          title: l10n.directPlayer,
          subtitle: l10n.directPlayerSubtitle,
          icon: Icons.play_circle_outline_rounded,
          onTap: () => onPlayerSelected('player4'),
        ),
    ];

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
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.md),
              options[i],
            ],
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
