import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/components/lesson_tile.dart';
import '../../../../../shared/cross_feature/downloads_shared.dart';
import '../../../../downloads/domain/entities/download_enums.dart';
import '../../../../downloads/domain/entities/downloaded_lesson.dart';
import '../../../domain/entities/lesson.dart';

/// Wires a [Lesson] + its live download status (from [downloadsProvider] /
/// [downloadProgressProvider]) into a [LessonTile].
///
/// Self-contained: doesn't touch `SectionsAccordion`'s private state, so it
/// moves out unchanged — a pure relocation, not a restructuring.
class LessonTileWrapper extends ConsumerWidget {
  final Lesson lesson;
  final String courseId;
  final String courseTitle;
  final bool isEnrolled;
  final bool isCompleted;
  final bool isLastWatched;
  final VoidCallback onTap;
  final ValueChanged<bool?> onToggleCompleted;
  final VoidCallback onDownload;

  const LessonTileWrapper({
    super.key,
    required this.lesson,
    required this.courseId,
    required this.courseTitle,
    required this.isEnrolled,
    required this.isCompleted,
    required this.isLastWatched,
    required this.onTap,
    required this.onToggleCompleted,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsAsync = ref.watch(downloadsProvider);
    final downloads = downloadsAsync.value ?? [];

    DownloadedLesson? download;
    for (final d in downloads) {
      if (d.lessonId == lesson.id.toString()) {
        download = d;
        break;
      }
    }

    bool isDownloaded = download?.status == DownloadStatus.completed;
    bool isDownloading = download?.status == DownloadStatus.downloading ||
        download?.status == DownloadStatus.pending;
    bool downloadFailed = download?.status == DownloadStatus.failed;
    double progressPct = download?.progress ?? 0.0;

    if (download != null &&
        (download.status == DownloadStatus.downloading ||
            download.status == DownloadStatus.pending)) {
      final progressAsync = ref.watch(downloadProgressProvider(download.id));
      final progress = progressAsync.value;
      if (progress != null) {
        isDownloading = progress.status == DownloadStatus.downloading ||
            progress.status == DownloadStatus.pending;
        isDownloaded = progress.status == DownloadStatus.completed;
        downloadFailed = progress.status == DownloadStatus.failed;
        progressPct = progress.progress;
      }
    }

    return LessonTile(
      title: lesson.title,
      completed: isCompleted,
      isLastWatched: isLastWatched,
      isLocked: !isEnrolled && !lesson.isPreview,
      isFree: !isEnrolled && lesson.isPreview,
      isEnrolled: isEnrolled,
      onTap: onTap,
      onToggleCompleted: onToggleCompleted,
      onDownload: onDownload,
      isDownloading: isDownloading,
      isDownloaded: isDownloaded,
      downloadFailed: downloadFailed,
      downloadProgress: progressPct,
    );
  }
}
