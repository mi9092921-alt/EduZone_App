import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../core/l10n/arb/app_localizations.dart';

class LessonTile extends StatelessWidget {
  final String title;
  final String? duration;
  final bool completed;
  final bool isLastWatched;
  final bool isLocked;
  final bool isFree;
  final bool isEnrolled;
  final VoidCallback? onTap;
  final ValueChanged<bool?>? onToggleCompleted;
  final VoidCallback? onDownload;
  final bool isDownloading;
  final bool isDownloaded;
  final bool downloadFailed;
  final double downloadProgress;

  const LessonTile({
    super.key,
    required this.title,
    this.duration,
    this.completed = false,
    this.isLastWatched = false,
    this.isLocked = false,
    this.isFree = false,
    this.isEnrolled = false,
    this.onTap,
    this.onToggleCompleted,
    this.onDownload,
    this.isDownloading = false,
    this.isDownloaded = false,
    this.downloadFailed = false,
    this.downloadProgress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      leading: _buildLeading(ds),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(
          color: isLocked
              ? ds.textMuted
              : (completed ? ds.textSecondary : ds.textPrimary),
          fontWeight: isLastWatched
              ? FontWeight.bold
              : (completed ? FontWeight.normal : FontWeight.w500),
        ),
      ),
      subtitle: duration != null
          ? Text(
              duration!,
              style: AppTextStyles.labelSmall.copyWith(color: ds.textMuted),
            )
          : null,
      trailing: _buildTrailing(ds, l10n, context),
    );
  }

  Widget _buildLeading(DesignSystemColors ds) {
    return Icon(
      Icons.play_circle_outline_rounded,
      color: isLocked ? ds.textMuted : ds.primary.withValues(alpha: 0.6),
      size: 22,
    );
  }

  Widget _buildTrailing(
    DesignSystemColors ds,
    AppLocalizations l10n,
    BuildContext context,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isFree && !isLocked)
          Container(
            margin: const EdgeInsetsDirectional.only(start: 8),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.hairline),
            decoration: BoxDecoration(
              color: ds.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(color: ds.success.withValues(alpha: 0.5)),
            ),
            child: Text(
              l10n.freeLabel,
              style: AppTextStyles.labelTiny.copyWith(color: ds.success),
            ),
          ),

        if (!isLocked) ...[
          if (isEnrolled) _buildDownloadIndicator(ds, context),
          Checkbox(
            value: completed,
            onChanged: onToggleCompleted,
            activeColor: ds.success,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.xxsBorder,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],

        if (isLocked)
          Icon(Icons.lock_outline_rounded, color: ds.textMuted, size: 18),
      ],
    );
  }

  Widget _buildDownloadIndicator(DesignSystemColors ds, BuildContext context) {
    if (isDownloaded) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Icon(Icons.check_circle_rounded, color: ds.success, size: 20),
      );
    }

    if (isDownloading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          value: downloadProgress > 0.0 ? downloadProgress / 100 : null,
          strokeWidth: 2,
          color: ds.primary,
        ),
      );
    }

    if (downloadFailed) {
      return AppIconButton(
        icon: Icons.error_outline_rounded,
        color: ds.error,
        iconSize: 20,
        semanticLabel: AppLocalizations.of(context)!.downloadRetry,
        onPressed: onDownload,
      );
    }

    return AppIconButton(
      icon: Icons.download_for_offline_outlined,
      iconSize: 20,
      color: ds.textMuted,
      semanticLabel: AppLocalizations.of(context)!.downloadLesson,
      onPressed: onDownload,
    );
  }
}