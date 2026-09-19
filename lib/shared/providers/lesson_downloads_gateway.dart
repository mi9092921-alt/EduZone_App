import 'package:flutter_riverpod/flutter_riverpod.dart';
// ProviderListenable is exported from misc.dart in the pinned Riverpod 3.x.
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../models/download_enums.dart';
import '../models/downloaded_lesson.dart';
import '../models/video_info.dart';

/// Minimal per-lesson download status snapshot the courses feature needs.
///
/// Exists so the contract can stay in `shared/` (core data can't cross into
/// features, and the full [DownloadProgress] entity lives in the downloads
/// feature domain). The gateway maps feature entities onto this view.
class LessonDownloadSnapshot {
  final DownloadStatus status;
  final double progress;

  const LessonDownloadSnapshot({
    required this.status,
    required this.progress,
  });
}

/// Cross-feature contract through which the `courses` feature reads
/// per-lesson download state and triggers downloads WITHOUT importing the
/// `downloads` feature (AGENTS import rules: features must not import
/// other features; cross-feature data routes through shared).
///
/// The concrete implementation lives in
/// `features/downloads/application/services/lesson_downloads_gateway_impl.dart`
/// and is injected at the composition root (`main.dart` ProviderScope
/// overrides). A null provider value (bare test containers, or the
/// downloads surface disabled) means "no download state available" —
/// consumers must degrade gracefully.
abstract interface class LessonDownloadsGateway {
  /// Reactive list of downloaded lessons for the current account.
  ProviderListenable<AsyncValue<List<DownloadedLesson>>> get downloads;

  /// Reactive live progress for one active download (null when the id has
  /// no live progress entry).
  ProviderListenable<AsyncValue<LessonDownloadSnapshot?>> progress(
    String downloadId,
  );

  /// Resolves streaming metadata (supported qualities, estimated sizes) for
  /// a lesson video ahead of the quality picker. [lessonId] lets the
  /// server-side video-info function authorize this specific lesson instead
  /// of trusting the URL alone. Throws on failure.
  Future<VideoInfo> getVideoInfo({
    required String videoUrl,
    required String lessonId,
  });

  /// Starts (or enqueues) a download for one lesson. Throws on failure —
  /// callers surface the mapped error message.
  Future<void> startDownload({
    required String lessonId,
    required String courseId,
    required String courseTitle,
    required String title,
    required String videoUrl,
    required VideoQuality quality,
    required bool ignoreWifiOnly,
  });
}

/// Composition-root injection point. Overridden in `main.dart` with the
/// downloads-feature implementation; stays null otherwise.
// Manual (non-codegen) provider — deliberate: this is composition-root
// plumbing for a cross-feature seam, mirroring the documented manual
// providers in shared/providers (download_network_policy_provider).
// check-ignore: provider defined outside application/providers by design.
// check-ignore: app-lifetime seam — the gateway holds the injected feature
// implementation for the whole session; an auto-dispose variant would tear
// down the shared contract whenever the last watcher unmounts.
final lessonDownloadsGatewayProvider =
    Provider<LessonDownloadsGateway?>((ref) => null); // check-ignore
