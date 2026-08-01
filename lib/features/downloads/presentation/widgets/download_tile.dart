import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/app_snackbar.dart';
import '../../domain/entities/download_enums.dart';
import '../../domain/entities/download_progress.dart';
import '../../domain/entities/downloaded_lesson.dart';
import '../providers/downloads_provider.dart';

/// Widget displaying a single downloaded lesson item.
class DownloadTile extends ConsumerWidget {
  final DownloadedLesson download;

  const DownloadTile({
    super.key,
    required this.download,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isActive = download.status == DownloadStatus.downloading ||
        download.status == DownloadStatus.paused;
    final isPlayable = download.status == DownloadStatus.completed;

    return AppCard(
      borderRadius: AppRadius.md,
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      onTap: isPlayable
          ? () => context.push(
                '${AppRoutes.courses}/downloads/offline-player/${download.id}',
              )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Status/play icon
              _buildLeadingIcon(ds),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      download.title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          _getStatusIcon(download.status),
                          size: 14,
                          color: _getStatusColor(download.status, ds),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          _getStatusText(download.status, l10n),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: _getStatusColor(download.status, ds),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          download.quality.label,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: ds.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildActionButtons(context, ref, ds, l10n),
            ],
          ),
          // Progress bar for active downloads
          if (isActive)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: _ActiveDownloadProgress(
                downloadId: download.id,
                fallback: _buildFallbackProgress(ds),
                buildProgress: (p) => _buildProgressSection(p, ds),
              ),
            ),
          // File info for completed downloads
          if (download.status == DownloadStatus.completed)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.storage, size: 14, color: ds.textSecondary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    DownloadProgressExtension.formatBytes(download.fileSize),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: ds.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.access_time, size: 14, color: ds.textSecondary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _getExpirationText(download.expiresAt, l10n),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: ds.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLeadingIcon(DesignSystemColors ds) {
    switch (download.status) {
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
            padding: EdgeInsets.all(10),
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

  Widget _buildProgressSection(DownloadProgress progress, DesignSystemColors ds) {
    return Column(
      children: [
        LinearProgressIndicator(
          value: progress.progress / 100,
          backgroundColor: ds.border,
          color: ds.primary,
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${progress.progress.toStringAsFixed(0)}%',
              style: AppTextStyles.bodySmall.copyWith(
                color: ds.textSecondary,
              ),
            ),
            Text(
              DownloadProgressExtension.formatBytes(progress.receivedBytes),
              style: AppTextStyles.bodySmall.copyWith(
                color: ds.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFallbackProgress(DesignSystemColors ds) {
    final progressValue = download.progress / 100;
    return Column(
      children: [
        LinearProgressIndicator(
          value: progressValue > 0 ? progressValue : null,
          backgroundColor: ds.border,
          color: ds.primary,
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${download.progress.toStringAsFixed(0)}%',
              style: AppTextStyles.bodySmall.copyWith(
                color: ds.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    DesignSystemColors ds,
    AppLocalizations l10n,
  ) {
    switch (download.status) {
      case DownloadStatus.downloading:
        return IconButton(
          icon: const Icon(Icons.pause),
          onPressed: () => _performAction(
            context,
            () => ref.read(downloadsProvider.notifier).pauseDownload(
                  download.id,
                ),
          ),
          tooltip: l10n.downloadPause,
        );
      case DownloadStatus.paused:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () => _performAction(
                context,
                () => ref.read(downloadsProvider.notifier).resumeDownload(
                      download.id,
                    ),
              ),
              tooltip: l10n.downloadResume,
            ),
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: () => _performAction(
                context,
                () => ref.read(downloadsProvider.notifier).cancelDownload(
                      download.id,
                    ),
              ),
              tooltip: l10n.downloadCancel,
            ),
          ],
        );
      case DownloadStatus.completed:
        return IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _showDeleteDialog(context, ref, l10n),
          tooltip: l10n.downloadsDeleteBtn,
        );
      case DownloadStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _performAction(
                context,
                () => ref.read(downloadsProvider.notifier).resumeDownload(
                      download.id,
                    ),
              ),
              tooltip: l10n.downloadRetry,
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: ds.error, size: 20),
              onPressed: () => _performAction(
                context,
                () => ref.read(downloadsProvider.notifier).deleteDownload(
                      download.id,
                    ),
              ),
              tooltip: l10n.downloadsDeleteBtn,
            ),
          ],
        );
      case DownloadStatus.pending:
        return IconButton(
          icon: const Icon(Icons.cancel),
          onPressed: () => _performAction(
            context,
            () => ref.read(downloadsProvider.notifier).cancelDownload(
                  download.id,
                ),
          ),
          tooltip: l10n.downloadCancel,
        );
    }
  }

  /// Runs a [DownloadsNotifier] action and surfaces a [Failure] (or any
  /// other error) as an error SnackBar instead of letting it become an
  /// unhandled Future rejection — mirrors the pattern already used for
  /// [DownloadsNotifier.startDownload] in sections_accordion.dart.
  Future<void> _performAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final message = e is Failure ? e.message : e.toString();
      AppSnackbar.showError(
        context: context,
        message: l10n.downloadActionFailed(message),
      );
    }
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      // Named dialogContext (not `context`) deliberately: it must NOT shadow
      // the outer screen `context`, because that outer context is what
      // _performAction needs to still be mounted after the dialog is popped
      // in order to show the error SnackBar.
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.downloadsDeleteTitle),
        content: Text(l10n.downloadsDeleteMsg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.downloadsCancelBtn),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _performAction(
                context,
                () => ref.read(downloadsProvider.notifier).deleteDownload(
                      download.id,
                    ),
              );
            },
            child: Text(l10n.downloadsDeleteBtn),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.pending:
        return Icons.schedule;
      case DownloadStatus.downloading:
        return Icons.downloading;
      case DownloadStatus.paused:
        return Icons.pause_circle;
      case DownloadStatus.completed:
        return Icons.check_circle;
      case DownloadStatus.failed:
        return Icons.error;
    }
  }

  Color _getStatusColor(DownloadStatus status, DesignSystemColors ds) {
    switch (status) {
      case DownloadStatus.pending:
        return ds.textSecondary;
      case DownloadStatus.downloading:
        return ds.primary;
      case DownloadStatus.paused:
        return AppColors.warning;
      case DownloadStatus.completed:
        return ds.success;
      case DownloadStatus.failed:
        return ds.error;
    }
  }

  String _getStatusText(DownloadStatus status, AppLocalizations l10n) {
    switch (status) {
      case DownloadStatus.pending:
        return l10n.downloadStatusPending;
      case DownloadStatus.downloading:
        return l10n.downloadStatusDownloading;
      case DownloadStatus.paused:
        return l10n.downloadStatusPaused;
      case DownloadStatus.completed:
        return l10n.downloadStatusCompleted;
      case DownloadStatus.failed:
        return l10n.downloadStatusFailed;
    }
  }

}

/// Separate ConsumerWidget so [downloadProgressProvider] is only watched
/// when the download is actually active (downloading or paused).
class _ActiveDownloadProgress extends ConsumerWidget {
  final String downloadId;
  final Widget fallback;
  final Widget Function(DownloadProgress) buildProgress;

  const _ActiveDownloadProgress({
    required this.downloadId,
    required this.fallback,
    required this.buildProgress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(downloadProgressProvider(downloadId));
    return progressAsync.when(
      data: (progress) => buildProgress(progress),
      loading: () => fallback,
      error: (_, _) => fallback,
    );
  }
}

extension on DownloadTile {
  String _getExpirationText(DateTime expiresAt, AppLocalizations l10n) {
    final now = DateTime.now();
    final difference = expiresAt.difference(now);

    if (difference.isNegative) {
      return l10n.downloadExpired;
    } else if (difference.inDays > 30) {
      return l10n.downloadNeverExpires;
    } else if (difference.inDays > 0) {
      return l10n.downloadExpiresInDays(difference.inDays);
    } else if (difference.inHours > 0) {
      return l10n.downloadExpiresInHours(difference.inHours);
    } else {
      return l10n.downloadExpiresSoon;
    }
  }
}
