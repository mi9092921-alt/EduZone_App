import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../design_system/design_system.dart';
import '../../data/models/video_info.dart';
import '../../domain/entities/download_enums.dart';
import '../../domain/entities/download_progress.dart';

/// Dialog for selecting video quality before download.
class QualitySelector extends ConsumerWidget {
  final String lessonTitle;
  final VideoInfo videoInfo;
  final List<VideoQuality> availableQualities;
  final Function(VideoQuality) onQualitySelected;

  const QualitySelector({
    super.key,
    required this.lessonTitle,
    required this.videoInfo,
    required this.availableQualities,
    required this.onQualitySelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.downloadSelectQuality),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lessonTitle,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.downloadEstimatedSizes,
            style: AppTextStyles.bodySmall.copyWith(
              color: ds.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...availableQualities.map((quality) {
            // Use actual size from API response, fall back to estimate
            final actualSize = videoInfo.getSizeForQuality(quality.label);
            final estimatedSize720p = videoInfo.estimatedSize720p ?? 0;
            final size =
                actualSize ?? (estimatedSize720p * quality.sizeMultiplier).toInt();
            return _QualityOption(
              quality: quality,
              size: size,
              isActualSize: actualSize != null,
              onTap: () {
                Navigator.pop(context);
                onQualitySelected(quality);
              },
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.downloadsCancelBtn),
        ),
      ],
    );
  }
}

class _QualityOption extends StatelessWidget {
  final VideoQuality quality;
  final int size;
  final bool isActualSize;
  final VoidCallback onTap;

  const _QualityOption({
    required this.quality,
    required this.size,
    required this.isActualSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(
              Icons.radio_button_unchecked,
              color: ds.primary,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                quality.displayName,
                style: AppTextStyles.bodyMedium,
              ),
            ),
            Text(
              size > 0
                  ? '${isActualSize ? '' : '~'}${DownloadProgressExtension.formatBytes(size)}'
                  : '',
              style: AppTextStyles.bodySmall.copyWith(
                color: ds.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the quality selector dialog.
Future<void> showQualitySelector({
  required BuildContext context,
  required String lessonTitle,
  required VideoInfo videoInfo,
  required List<VideoQuality> availableQualities,
  required Function(VideoQuality) onQualitySelected,
}) {
  return showDialog(
    context: context,
    builder: (context) => QualitySelector(
      lessonTitle: lessonTitle,
      videoInfo: videoInfo,
      availableQualities: availableQualities,
      onQualitySelected: onQualitySelected,
    ),
  );
}
