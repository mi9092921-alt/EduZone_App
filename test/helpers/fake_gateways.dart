import 'package:app/shared/models/app_notification.dart';
import 'package:app/shared/models/download_enums.dart';
import 'package:app/shared/models/downloaded_lesson.dart';
import 'package:app/shared/models/video_info.dart';
import 'package:app/shared/providers/home_notifications_gateway.dart';
import 'package:app/shared/providers/lesson_downloads_gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateController / StateNotifierProvider live in the legacy export as of
// Riverpod 3.x. The fakes use them purely as reactive, externally-mutable
// containers for test state — no feature provider is involved.
import 'package:flutter_riverpod/legacy.dart';
// `ProviderListenable` is exported from misc.dart in the resolved Riverpod
// version (not from the main flutter_riverpod.dart export list).
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

// ─── Fixtures ────────────────────────────────────────────────────────────────

/// Minimal [AppNotification] fixture. Defaults to unread; pass [isRead] for
/// read ones.
AppNotification buildNotification({
  String id = 'n1',
  bool isRead = false,
  String title = 'Test notification',
  String userId = 'user-1',
}) {
  return AppNotification(
    id: id,
    userId: userId,
    tenantId: 'tenant-1',
    isRead: isRead,
    createdAt: DateTime(2026),
    details: NotificationDetails(title: title, body: 'Body for $title'),
  );
}

/// Minimal [DownloadedLesson] fixture for gateway-backed widget tests.
DownloadedLesson buildDownloadedLesson({
  String lessonId = 'lesson-1',
  DownloadStatus status = DownloadStatus.completed,
  double progress = 100.0,
  String courseId = 'course-1',
}) {
  final now = DateTime(2026);
  return DownloadedLesson(
    id: 'dl-$lessonId',
    lessonId: lessonId,
    courseId: courseId,
    title: 'Downloaded lesson',
    localPath: '/tmp/$lessonId',
    encryptedPath: '/tmp/$lessonId.enc',
    videoUrl: 'https://example.com/$lessonId.mp4',
    quality: VideoQuality.p144,
    fileSize: 1024,
    status: status,
    progress: progress,
    downloadedAt: now,
    expiresAt: now.add(const Duration(days: 30)),
  );
}

/// Minimal [VideoInfo] fixture: one muxed format per requested quality so
/// the quality selector has something to offer.
VideoInfo buildVideoInfo({List<VideoQuality>? qualities}) {
  final labels = qualities ?? const [VideoQuality.p720];
  return VideoInfo(
    title: 'Fixture lesson video',
    duration: 600,
    formats: labels
        .map(
          (q) => VideoFormat(
            itag: 18,
            quality: q.label,
            height: int.tryParse(q.label.replaceAll('p', '')),
            fps: 30,
            ext: 'mp4',
            sizeBytes: 1024 * 1024,
            hasAudio: true,
            requiresMerge: false,
            videoUrl: 'https://example.com/video-${q.label}.mp4',
          ),
        )
        .toList(),
    defaultDownloadQuality: labels.first.label,
    source: 'fresh',
    platform: 'YouTube',
    timeMs: 0,
  );
}

// ─── Fakes ───────────────────────────────────────────────────────────────────

/// In-memory [HomeNotificationsGateway] for widget tests.
///
/// The notification list is backed by a [StateController] the fake owns,
/// surfaced through a [StateNotifierProvider] so `ref.watch(fake.notifications)`
/// re-evaluates whenever [setNotifications] / [markAllRead] / [markAsRead]
/// mutate it — no notifications-feature provider (and no Supabase) involved.
class FakeHomeNotificationsGateway implements HomeNotificationsGateway {
  FakeHomeNotificationsGateway({List<AppNotification>? initial}) {
    _controller = StateController<AsyncValue<List<AppNotification>>>(
      AsyncValue.data(List<AppNotification>.unmodifiable(initial ?? const [])),
    );
    _notificationsProvider = StateNotifierProvider<
        StateController<AsyncValue<List<AppNotification>>>,
        AsyncValue<List<AppNotification>>>((ref) => _controller);
    _unreadCountProvider = Provider<int>(
      (ref) => ref
          .watch(_notificationsProvider)
          .value
          ?.where((n) => !n.isRead)
          .length ?? 0,
    );
  }

  late final StateController<AsyncValue<List<AppNotification>>> _controller;
  late final StateNotifierProvider<
      StateController<AsyncValue<List<AppNotification>>>,
      AsyncValue<List<AppNotification>>> _notificationsProvider;
  late final Provider<int> _unreadCountProvider;

  /// Every markAsRead invocation, in call order.
  final List<({String notificationId, String userId})> markAsReadCalls = [];

  /// Value the next [markAsRead] resolves with (success by default).
  bool markAsReadResult = true;

  /// Refresh requests received (the real gateway invalidates the
  /// notifications provider here; the fake just counts).
  int refreshCalls = 0;

  /// Current notification list (latest set/mark state).
  List<AppNotification> get notificationsList =>
      _controller.state.value ?? const [];

  @override
  ProviderListenable<AsyncValue<List<AppNotification>>> get notifications =>
      _notificationsProvider;

  @override
  ProviderListenable<int> get unreadCount => _unreadCountProvider;

  /// Replaces the notification list (unread count re-derives automatically).
  void setNotifications(List<AppNotification> list) {
    _controller.state = AsyncValue.data(list);
  }

  /// Marks every notification read in place.
  void markAllRead() {
    setNotifications(
      notificationsList
          .map((n) => n.copyWith(isRead: true, readAt: DateTime(2026)))
          .toList(),
    );
  }

  @override
  Future<bool> markAsRead({
    required String notificationId,
    required String userId,
  }) async {
    markAsReadCalls.add((notificationId: notificationId, userId: userId));
    if (!markAsReadResult) return false;
    // Flip the matching notification so consumers that re-watch after a
    // successful mark-as-read observe the new state.
    setNotifications(
      notificationsList
          .map(
            (n) => n.id == notificationId
                ? n.copyWith(isRead: true, readAt: DateTime(2026))
                : n,
          )
          .toList(),
    );
    return true;
  }

  @override
  void refresh() {
    refreshCalls++;
  }
}

/// In-memory [LessonDownloadsGateway] for widget tests.
///
/// `downloads` is backed by a [StateController] (mutate via [setDownloads]);
/// `progress(id)` hands out a cached per-id [StateNotifierProvider] so
/// `ref.watch(gateway.progress(id))` is stable across widget rebuilds.
class FakeLessonDownloadsGateway implements LessonDownloadsGateway {
  FakeLessonDownloadsGateway({List<DownloadedLesson>? initialDownloads}) {
    _downloadsController =
        StateController<AsyncValue<List<DownloadedLesson>>>(
          AsyncValue.data(
            List<DownloadedLesson>.unmodifiable(initialDownloads ?? const []),
          ),
        );
    _downloadsProvider = StateNotifierProvider<
        StateController<AsyncValue<List<DownloadedLesson>>>,
        AsyncValue<List<DownloadedLesson>>>((ref) => _downloadsController);
  }

  late final StateController<AsyncValue<List<DownloadedLesson>>>
      _downloadsController;
  late final StateNotifierProvider<
      StateController<AsyncValue<List<DownloadedLesson>>>,
      AsyncValue<List<DownloadedLesson>>> _downloadsProvider;

  final Map<String, StateController<AsyncValue<LessonDownloadSnapshot?>>>
      _progressControllers = {};
  final Map<String,
          StateNotifierProvider<
              StateController<AsyncValue<LessonDownloadSnapshot?>>,
              AsyncValue<LessonDownloadSnapshot?>>> _progressProviders = {};

  /// Every startDownload invocation, in call order.
  final List<({
    String lessonId,
    String courseId,
    String courseTitle,
    String title,
    String videoUrl,
    VideoQuality quality,
    bool ignoreWifiOnly,
  })> startDownloadCalls = [];

  /// When non-null, the next [startDownload] throws it.
  Object? startDownloadError;

  /// When non-null, the next [getVideoInfo] resolves with it instead of the
  /// default fixture.
  VideoInfo? videoInfoResult;

  /// When non-null, the next [getVideoInfo] throws it.
  Object? getVideoInfoError;

  /// Current downloaded-lesson list (latest set state).
  List<DownloadedLesson> get downloadsList =>
      _downloadsController.state.value ?? const [];

  @override
  ProviderListenable<AsyncValue<List<DownloadedLesson>>> get downloads =>
      _downloadsProvider;

  /// Replaces the downloaded-lessons list.
  void setDownloads(List<DownloadedLesson> list) {
    _downloadsController.state = AsyncValue.data(list);
  }

  /// Sets (or clears) the live progress snapshot for one download id.
  void setProgress(String downloadId, LessonDownloadSnapshot? snapshot) {
    _progressControllerFor(downloadId).state = AsyncValue.data(snapshot);
  }

  StateController<AsyncValue<LessonDownloadSnapshot?>>
      _progressControllerFor(String downloadId) {
    return _progressControllers.putIfAbsent(
      downloadId,
      () => StateController<AsyncValue<LessonDownloadSnapshot?>>(
        const AsyncValue.data(null),
      ),
    );
  }

  @override
  ProviderListenable<AsyncValue<LessonDownloadSnapshot?>> progress(
    String downloadId,
  ) {
    _progressControllerFor(downloadId); // ensure the controller exists first
    return _progressProviders.putIfAbsent(downloadId, () {
      final controller = _progressControllers[downloadId]!;
      return StateNotifierProvider<
          StateController<AsyncValue<LessonDownloadSnapshot?>>,
          AsyncValue<LessonDownloadSnapshot?>>((ref) => controller);
    });
  }

  @override
  Future<VideoInfo> getVideoInfo({
    required String videoUrl,
    required String lessonId,
  }) async {
    final error = getVideoInfoError;
    if (error != null) throw error;
    return videoInfoResult ?? buildVideoInfo();
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
  }) async {
    final error = startDownloadError;
    if (error != null) {
      throw error;
    }
    startDownloadCalls.add((
      lessonId: lessonId,
      courseId: courseId,
      courseTitle: courseTitle,
      title: title,
      videoUrl: videoUrl,
      quality: quality,
      ignoreWifiOnly: ignoreWifiOnly,
    ));
  }
}
