import 'package:app/design_system/design_system.dart';
import 'package:app/features/downloads/domain/entities/download_enums.dart';
import 'package:flutter/material.dart';

/// The circular status icon shown at the start of a [DownloadTile] row.
///
/// Extracted from `download_tile.dart`'s private `_buildLeadingIcon`
/// method — purely a function of [status], so it's promoted to its own
/// widget with no other dependencies.
class DownloadLeadingIcon extends StatelessWidget {
  final DownloadStatus status;

  const DownloadLeadingIcon({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);

    switch (status) {
      case DownloadStatus.completed:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ds.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.play_arrow_rounded,
            color: ds.primary,
            size: 22,
          ),
        );
      case DownloadStatus.downloading:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ds.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Padding(
            padding: EdgeInsets.all(AppSpacing.iconBadgePadding),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case DownloadStatus.paused:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.pause_rounded,
            color: AppColors.warning,
            size: 22,
          ),
        );
      case DownloadStatus.failed:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ds.error.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.error_outline_rounded,
            color: ds.error,
            size: 22,
          ),
        );
      case DownloadStatus.pending:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ds.textSecondary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.schedule_rounded,
            color: ds.textSecondary,
            size: 22,
          ),
        );
    }
  }
}
