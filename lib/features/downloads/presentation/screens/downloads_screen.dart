import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/app_snackbar.dart';
import '../../application/providers/downloads_provider.dart';
import '../../domain/entities/download_enums.dart';
import '../../domain/entities/downloaded_lesson.dart';
import '../widgets/download_tile.dart';

/// Screen displaying all downloaded lessons grouped by status.
String resolveCourseGroupTitle(DownloadedLesson download) {
  final courseTitle = download.courseTitle.trim();
  return courseTitle.isNotEmpty ? courseTitle : download.courseId;
}

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

/// Flattened row description for the downloads list.
///
/// Building this list is cheap (no widgets are constructed yet) so it can
/// be done eagerly; the actual widgets are only built lazily, on demand,
/// by ListView.builder's itemBuilder -- see PERF-001.
enum _DownloadRowType { activeHeader, courseHeader, tile, divider }

class _DownloadRow {
  final _DownloadRowType type;
  final String? title;
  final DownloadedLesson? download;

  const _DownloadRow.activeHeader(String this.title)
      : type = _DownloadRowType.activeHeader,
        download = null;
  const _DownloadRow.courseHeader(String this.title)
      : type = _DownloadRowType.courseHeader,
        download = null;
  const _DownloadRow.tile(DownloadedLesson this.download)
      : type = _DownloadRowType.tile,
        title = null;
  const _DownloadRow.divider()
      : type = _DownloadRowType.divider,
        title = null,
        download = null;
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(downloadsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final downloadsAsync = ref.watch(downloadsProvider);
    final storageUsedAsync = ref.watch(totalStorageUsedProvider);

    return AppScreen(
      scrollable: false,
      appBar: AppBar(
        elevation: 0,
        title: Text(l10n.downloadsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            onPressed: () => _showCleanupDialog(context, l10n),
            tooltip: l10n.downloadsCleanup,
          ),
        ],
      ),
      child: Column(
        children: [
          // Storage usage indicator
          storageUsedAsync.when(
            data: (totalBytes) =>
                _buildStorageIndicator(context, totalBytes, ds, l10n),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const Divider(height: 1),
          // Downloads list
          Expanded(
            child: downloadsAsync.when(
              data: (downloads) {
                if (downloads.isEmpty) {
                  return _buildEmptyState(context, ds, l10n);
                }
                return _buildDownloadsList(downloads, l10n);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _buildErrorState(context, ds, l10n, error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageIndicator(
    BuildContext context,
    int totalBytes,
    DesignSystemColors ds,
    AppLocalizations l10n,
  ) {
    final totalMB = totalBytes / (1024 * 1024);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: ds.surface2,
      child: Row(
        children: [
          Icon(Icons.storage, color: ds.primary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text(
            l10n.downloadsStorageUsed(totalMB.toStringAsFixed(1)),
            style: AppTextStyles.bodyMedium.copyWith(
              color: ds.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsList(
    List<DownloadedLesson> downloads,
    AppLocalizations l10n,
  ) {
    // Separate active (in-progress) from completed/failed downloads
    final active = downloads
        .where((d) =>
            d.status == DownloadStatus.downloading ||
            d.status == DownloadStatus.paused ||
            d.status == DownloadStatus.pending)
        .toList();
    final completed = downloads
        .where((d) =>
            d.status == DownloadStatus.completed ||
            d.status == DownloadStatus.failed)
        .toList();

    // Group completed by courseId
    final grouped = <String, List<DownloadedLesson>>{};
    for (final download in completed) {
      grouped.putIfAbsent(download.courseId, () => []).add(download);
    }

    // Flatten into a row-description list first (cheap: no widgets built
    // yet), then hand it to ListView.builder so items are laid out lazily
    // instead of the whole (possibly large) list being built up front on
    // every rebuild. See PERF-001.
    final rows = <_DownloadRow>[];
    if (active.isNotEmpty) {
      rows.add(_DownloadRow.activeHeader(l10n.downloadStatusDownloading));
      for (final download in active) {
        rows.add(_DownloadRow.tile(download));
      }
      if (completed.isNotEmpty) rows.add(const _DownloadRow.divider());
    }
    for (final entry in grouped.entries) {
      final courseDownloads = entry.value;
      rows.add(_DownloadRow.courseHeader(
        l10n.downloadCourseGroup(resolveCourseGroupTitle(courseDownloads.first)),
      ));
      for (final download in courseDownloads) {
        rows.add(_DownloadRow.tile(download));
      }
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(downloadsProvider.notifier).refresh(),
      child: ListView.builder(
        itemCount: rows.length,
        itemBuilder: (context, index) => _buildDownloadRow(context, rows[index]),
      ),
    );
  }

  Widget _buildDownloadRow(BuildContext context, _DownloadRow row) {
    switch (row.type) {
      case _DownloadRowType.activeHeader:
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Text(
            row.title!,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.of(context).primary,
            ),
          ),
        );
      case _DownloadRowType.courseHeader:
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            row.title!,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      case _DownloadRowType.tile:
        return DownloadTile(download: row.download!);
      case _DownloadRowType.divider:
        return const Divider(height: 24);
    }
  }

  Widget _buildEmptyState(
    BuildContext context,
    DesignSystemColors ds,
    AppLocalizations l10n,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.download_outlined,
            size: 64,
            color: ds.textSecondary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.downloadsEmpty,
            style: AppTextStyles.h3.copyWith(
              color: ds.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.downloadsEmptyHint,
            style: AppTextStyles.bodyMedium.copyWith(
              color: ds.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    DesignSystemColors ds,
    AppLocalizations l10n,
    Object error,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: ds.error,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.downloadsError,
            style: AppTextStyles.h3.copyWith(
              color: ds.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            error.toString(),
            style: AppTextStyles.bodyMedium.copyWith(
              color: ds.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: () {
              ref.read(downloadsProvider.notifier).refresh();
            },
            child: Text(l10n.downloadsRetry),
          ),
        ],
      ),
    );
  }

  void _showCleanupDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      // Named dialogContext deliberately: it must not shadow the outer
      // screen `context`, since the error SnackBar needs a context that is
      // still mounted after this dialog is popped.
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.downloadsCleanupTitle),
        content: Text(l10n.downloadsCleanupMsg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.downloadsCancelBtn),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _performCleanup(context, l10n);
            },
            child: Text(l10n.downloadsCleanup),
          ),
        ],
      ),
    );
  }

  /// Runs cleanupExpired and surfaces a [Failure] (or any other error) as an
  /// error SnackBar instead of letting it become an unhandled Future
  /// rejection.
  Future<void> _performCleanup(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    try {
      await ref.read(downloadsProvider.notifier).cleanupExpired();
    } catch (e) {
      if (!context.mounted) return;
      final message = e is Failure ? e.message : e.toString();
      AppSnackbar.showError(
        context: context,
        message: l10n.downloadActionFailed(message),
      );
    }
  }
}
