import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/feature_flags/feature_flag_keys.dart';
import '../../../../../core/feature_flags/feature_flags_provider.dart';
import '../../../../../shared/components/lesson_tile.dart';
import '../../../../../shared/models/download_enums.dart';
import '../../../../../shared/models/downloaded_lesson.dart';
import '../../../../../shared/models/lesson.dart';
import '../../../../../shared/providers/lesson_downloads_gateway.dart';

/// Wires a [Lesson] + its live download status (from the shared
/// [LessonDownloadsGateway] contract) into a [LessonTile].
///
/// Self-contained: doesn't touch `SectionsAccordion`'s private state, so it
/// moves out unchanged — a pure relocation, not a restructuring.
///
/// Download state is read through the shared gateway (implemented by the
/// downloads feature, injected at the composition root) — courses does not
/// import the downloads feature. A null gateway (downloads surface
/// unavailable, bare test container) degrades to "no download data".
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
    final gateway = ref.watch(lessonDownloadsGatewayProvider);
    final downloadsAsync = gateway == null
        ? const AsyncValue<List<DownloadedLesson>>.data([])
        : ref.watch(gateway.downloads);
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

    if (gateway != null &&
        download != null &&
        (download.status == DownloadStatus.downloading ||
            download.status == DownloadStatus.pending)) {
      final progressAsync = ref.watch(gateway.progress(download.id));
      final snapshot = progressAsync.value;
      if (snapshot != null) {
        isDownloading = snapshot.status == DownloadStatus.downloading ||
            snapshot.status == DownloadStatus.pending;
        isDownloaded = snapshot.status == DownloadStatus.completed;
        downloadFailed = snapshot.status == DownloadStatus.failed;
        progressPct = snapshot.progress;
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
      // Remote kill switch (FeatureFlagKey.coursesDownloads): false removes
      // the download indicator entirely; playback/progress UI is unaffected.
      showDownload: ref
          .watch(featureFlagsProvider)
          .isEnabled(FeatureFlagKey.coursesDownloads),
      isDownloading: isDownloading,
      isDownloaded: isDownloaded,
      downloadFailed: downloadFailed,
      downloadProgress: progressPct,
    );
  }
}
