import 'package:flutter_riverpod/flutter_riverpod.dart';
// ProviderListenable is exported from misc.dart in the pinned Riverpod 3.x.
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../../../../shared/models/download_enums.dart';
import '../../../../../shared/models/downloaded_lesson.dart';
import '../../../../../shared/models/video_info.dart';
import '../../../../../shared/providers/lesson_downloads_gateway.dart';
import '../providers/downloads_provider.dart';

/// Downloads-feature implementation of the lesson download gateway
/// contract (see [LessonDownloadsGateway]). Bridges the feature's own
/// providers onto the shared seam without courses importing this feature.
class LessonDownloadsGatewayImpl implements LessonDownloadsGateway {
  LessonDownloadsGatewayImpl(this._ref);

  final Ref _ref;

  @override
  ProviderListenable<AsyncValue<List<DownloadedLesson>>> get downloads =>
      downloadsProvider;

  @override
  ProviderListenable<AsyncValue<LessonDownloadSnapshot?>> progress(
    String downloadId,
  ) {
    // Map the feature's DownloadProgress entity onto the shared snapshot
    // view so the contract never leaks feature domain types.
    return downloadProgressProvider(downloadId).select(
      (async) => async.whenData(
        (progress) => LessonDownloadSnapshot(
          status: progress.status,
          progress: progress.progress,
        ),
      ),
    );
  }

  @override
  Future<VideoInfo> getVideoInfo({
    required String videoUrl,
    required String lessonId,
  }) {
    return _ref.read(downloadRemoteDataSourceProvider).getVideoInfo(
          videoUrl,
          lessonId: lessonId,
        );
  }

  @override
  Future<void> startDownload({
    required String lessonId,
    required String courseId,
    required String courseTitle,
    required String title,
    required String videoUrl,
    required VideoQuality quality,
    required bool ignoreWifiOnly,
  }) {
    return _ref.read(downloadsProvider.notifier).startDownload(
          lessonId: lessonId,
          courseId: courseId,
          courseTitle: courseTitle,
          title: title,
          videoUrl: videoUrl,
          quality: quality,
          ignoreWifiOnly: ignoreWifiOnly,
        );
  }
}
