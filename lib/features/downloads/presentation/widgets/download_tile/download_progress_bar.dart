import 'package:app/design_system/design_system.dart';
import 'package:app/features/downloads/domain/entities/download_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/downloads_provider.dart';

/// The linear progress bar + percent/bytes row shown under an active
/// download tile.
///
/// Extracted from `download_tile.dart`, which previously had two
/// near-identical private methods for this — `_buildProgressSection`
/// (driven by the live [DownloadProgress] stream, always a determinate
/// bar, shows a bytes-received label) and `_buildFallbackProgress`
/// (driven by the last known `DownloadedLesson.progress` value while the
/// stream is loading/erroring, shows an indeterminate bar at 0%, no bytes
/// label since none are available yet). This single widget now covers
/// both call sites via [indeterminateAtZero] and the optional
/// [bytesLabel], instead of duplicating the `Column`/`LinearProgressIndicator`/
/// `Row` layout twice.
class DownloadProgressBar extends StatelessWidget {
  /// 0–100.
  final double progressPercent;

  /// Formatted "received / total" bytes label — only available once the
  /// live [DownloadProgress] stream has emitted, so `null` for the
  /// fallback case.
  final String? bytesLabel;

  /// When true (the fallback case) and [progressPercent] is `0`, the bar
  /// renders indeterminate (`value: null`) instead of a zero-width
  /// determinate bar.
  final bool indeterminateAtZero;

  const DownloadProgressBar({
    super.key,
    required this.progressPercent,
    this.bytesLabel,
    this.indeterminateAtZero = false,
  });

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);
    final normalized = progressPercent / 100;
    final showIndeterminate = indeterminateAtZero && progressPercent <= 0;

    return Column(
      children: [
        LinearProgressIndicator(
          value: showIndeterminate ? null : normalized,
          backgroundColor: ds.border,
          color: ds.primary,
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${progressPercent.toStringAsFixed(0)}%',
              style: AppTextStyles.bodySmall.copyWith(
                color: ds.textSecondary,
              ),
            ),
            if (bytesLabel != null)
              Text(
                bytesLabel!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: ds.textSecondary,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Watches the live [downloadProgressProvider] stream for [downloadId] and
/// renders a [DownloadProgressBar] driven by it, falling back to
/// [fallbackProgressPercent] (the last known `DownloadedLesson.progress`)
/// while the stream is loading or has errored.
///
/// Extracted from `download_tile.dart` (previously private
/// `_ActiveDownloadProgress`) and promoted to public. Kept as a separate
/// [ConsumerWidget] so [downloadProgressProvider] is only watched when the
/// download is actually active (downloading or paused) — unchanged from
/// the original design.
class ActiveDownloadProgress extends ConsumerWidget {
  final String downloadId;
  final double fallbackProgressPercent;

  const ActiveDownloadProgress({
    super.key,
    required this.downloadId,
    required this.fallbackProgressPercent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(downloadProgressProvider(downloadId));

    return progressAsync.when(
      data: (progress) => DownloadProgressBar(
        progressPercent: progress.progress,
        bytesLabel: DownloadProgressExtension.formatBytes(
          progress.receivedBytes,
        ),
      ),
      loading: () => DownloadProgressBar(
        progressPercent: fallbackProgressPercent,
        indeterminateAtZero: true,
      ),
      error: (_, _) => DownloadProgressBar(
        progressPercent: fallbackProgressPercent,
        indeterminateAtZero: true,
      ),
    );
  }
}
