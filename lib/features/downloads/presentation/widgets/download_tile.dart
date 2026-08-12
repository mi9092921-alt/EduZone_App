import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/download_enums.dart';
import '../../domain/entities/download_progress.dart';
import '../../domain/entities/downloaded_lesson.dart';
import 'download_tile/download_action_buttons.dart';
import 'download_tile/download_leading_icon.dart';
import 'download_tile/download_progress_bar.dart';
import 'download_tile/download_status_presentation.dart';

// ─────────────────────────────────────────────────────────────────────────
// كان هذا الملف أصلاً 500 سطر. بعد التقسيم:
//   - download_tile.dart                          → هذا الملف: التخطيط فقط
//   - download_tile/download_status_presentation.dart → أيقونة/لون/نص الحالة
//                                                     + formatDownloadExpiration()
//                                                     (منطق صرف قابل للاختبار)
//   - download_tile/download_leading_icon.dart     → الأيقونة الدائرية في البداية
//   - download_tile/download_progress_bar.dart     → شريط التقدّم الموحّد
//                                                     (كان مكرراً بمكانين)
//                                                     + ActiveDownloadProgress
//   - download_tile/download_action_buttons.dart   → أزرار الإجراءات
//                                                     + performDownloadAction()
//                                                     + showDownloadDeleteDialog()
// ─────────────────────────────────────────────────────────────────────────

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
              DownloadLeadingIcon(status: download.status),
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
                          DownloadStatusPresentation.icon(download.status),
                          size: 14,
                          color: DownloadStatusPresentation.color(
                            download.status,
                            ds,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          DownloadStatusPresentation.text(
                            download.status,
                            l10n,
                          ),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: DownloadStatusPresentation.color(
                              download.status,
                              ds,
                            ),
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
              DownloadActionButtons(
                downloadId: download.id,
                status: download.status,
              ),
            ],
          ),
          // Progress bar for active downloads
          if (isActive)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: ActiveDownloadProgress(
                downloadId: download.id,
                fallbackProgressPercent: download.progress,
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
                    formatDownloadExpiration(download.expiresAt, l10n),
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
}
