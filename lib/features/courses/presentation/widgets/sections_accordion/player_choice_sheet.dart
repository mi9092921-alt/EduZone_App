import 'package:flutter/material.dart';

import '../../../../../core/l10n/arb/app_localizations.dart';
import '../../../../../design_system/design_system.dart';
import 'player_option_tile.dart';

/// Opens the "choose a player" bottom sheet with the four available player
/// implementations. [onPlayerSelected] is called with `'youtube'`,
/// `'proxy'`, `'modern'`, or `'player4'` once the user picks one.
Future<void> showPlayerChoiceSheet(
  BuildContext context, {
  required ValueChanged<String> onPlayerSelected,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        PlayerChoiceSheet(onPlayerSelected: onPlayerSelected),
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

  const PlayerChoiceSheet({super.key, required this.onPlayerSelected});

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
            'اختر المشغل',
            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.lg),
          PlayerOptionTile(
            title: 'YouTube Player',
            subtitle: 'مشغّل Flutter القياسي',
            icon: Icons.smart_display_rounded,
            onTap: () => onPlayerSelected('youtube'),
          ),
          const SizedBox(height: AppSpacing.md),
          PlayerOptionTile(
            title: 'Proxy Player',
            subtitle: 'مشغّل بدون إعلانات',
            icon: Icons.shield_rounded,
            onTap: () => onPlayerSelected('proxy'),
          ),
          const SizedBox(height: AppSpacing.md),
          PlayerOptionTile(
            title: 'Modern Player',
            subtitle: 'مشغّل WebView مع حذف العناصر',
            icon: Icons.auto_awesome_rounded,
            onTap: () => onPlayerSelected('modern'),
          ),
          const SizedBox(height: AppSpacing.md),
          PlayerOptionTile(
            title: l10n.directPlayer,
            subtitle: l10n.directPlayerSubtitle,
            icon: Icons.play_circle_outline_rounded,
            onTap: () => onPlayerSelected('player4'),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
