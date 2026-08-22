import 'package:app/core/constants/app_constants.dart';
import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'player_type.dart';

/// App-bar action that opens a bottom sheet letting the user switch
/// between the 3 available video-player backends.
///
/// Extracted from `video_player_screen.dart` (previously private
/// `_PlayerSwitchButton`) — depends only on [courseId]/[lessonId]/
/// [playerType], so it's independently reusable/testable.
class PlayerSwitchButton extends StatelessWidget {
  final String courseId;
  final String lessonId;
  final PlayerType playerType;

  const PlayerSwitchButton({
    super.key,
    required this.courseId,
    required this.lessonId,
    required this.playerType,
  });

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      icon: playerType == PlayerType.modern
          ? Icons.auto_awesome_rounded
          : playerType == PlayerType.player4
          ? Icons.play_circle_outline_rounded
          : Icons.smart_display_rounded,
      semanticLabel: AppLocalizations.of(context)!.videoSwitchPlayer,
      onPressed: () => _showSwitchSheet(context),
    );
  }

  void _showSwitchSheet(BuildContext context) {
    final ds = AppColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ds.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xl2,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
              AppLocalizations.of(context)!.chooseVideoPlayer,
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: AppSpacing.lg),
            PlayerOptionTile(
              icon: Icons.smart_display_rounded,
              title: AppLocalizations.of(context)!.youtubePlayer,
              subtitle: AppLocalizations.of(context)!.youtubePlayerSubtitle,
              isActive: playerType == PlayerType.youtube,
              onTap: () {
                context.pop();
                if (playerType != PlayerType.youtube) {
                  context.pushReplacement(
                    '${AppRoutes.courses}/$courseId/lesson/$lessonId',
                  );
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            PlayerOptionTile(
              icon: Icons.auto_awesome_rounded,
              title: AppLocalizations.of(context)!.modernPlayer,
              subtitle: AppLocalizations.of(context)!.modernPlayerSubtitle,
              isActive: playerType == PlayerType.modern,
              onTap: () {
                context.pop();
                if (playerType != PlayerType.modern) {
                  context.pushReplacement(
                    '${AppRoutes.courses}/$courseId/lesson3/$lessonId',
                  );
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            PlayerOptionTile(
              icon: Icons.play_circle_outline_rounded,
              title: AppLocalizations.of(context)!.directPlayer,
              subtitle: AppLocalizations.of(context)!.directPlayerSubtitle,
              isActive: playerType == PlayerType.player4,
              onTap: () {
                context.pop();
                if (playerType != PlayerType.player4) {
                  context.pushReplacement(
                    '${AppRoutes.courses}/$courseId/lesson4/$lessonId',
                  );
                }
              },
            ),
          ],
          ),
        ),
      ),
    );
  }
}

/// A single selectable row inside the player-switch bottom sheet.
///
/// Extracted from `video_player_screen.dart` (previously private
/// `_PlayerOption`).
class PlayerOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isActive;
  final VoidCallback onTap;

  const PlayerOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.1)
              : ds.surface2,
          borderRadius: AppRadius.mdBorder,
          border: Border.all(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.5)
                : ds.border,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isActive ? AppColors.primary : ds.textSecondary),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: ds.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
