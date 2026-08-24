import 'dart:convert';
import 'package:crypto/crypto.dart' show md5;

// ─── Risk Levels & Categories ────────────────────────────────────────────────

enum EventRiskLevel { low, medium, high, critical }

enum EventCategory { auth, course, video, todo, navigation, system, download }

// ─── Base Event (Sealed) ─────────────────────────────────────────────────────

/// Base class for all trackable application events.
///
/// Each event generates a unique [idempotencyKey] from its type,
/// timestamp, and entity ID to prevent duplicate processing.
sealed class AppEvent {
  final DateTime timestamp;
  final String? userId;
  final String? tenantId;
  final String? deviceId;

  const AppEvent({
    required this.timestamp,
    this.userId,
    this.tenantId,
    this.deviceId,
  });

  /// The activity_type string sent to Supabase `activity_log_queue`.
  String get activityType;

  /// Event category for handler routing.
  EventCategory get category;

  /// Risk level for audit tagging.
  EventRiskLevel get riskLevel => EventRiskLevel.low;

  /// Entity ID for deduplication (e.g. courseId, lessonId, todoId).
  String get entityId => '';

  /// Additional structured data sent as `details` JSONB.
  Map<String, dynamic> get details => {};

  /// Deduplication key: hash(type + timestamp_ms + entityId).
  /// Prevents duplicate events from rapid re-renders or double-taps.
  String get idempotencyKey {
    final raw = '$activityType:${timestamp.millisecondsSinceEpoch}:$entityId';
    return md5.convert(utf8.encode(raw)).toString();
  }
}

// ─── Auth Events ─────────────────────────────────────────────────────────────

class AuthLoginEvent extends AppEvent {
  final String loginMethod;

  const AuthLoginEvent({
    required super.timestamp,
    super.userId,
    super.tenantId,
    super.deviceId,
    this.loginMethod = 'email',
  });

  @override
  String get activityType => 'auth.login';
  @override
  EventCategory get category => EventCategory.auth;
  @override
  EventRiskLevel get riskLevel => EventRiskLevel.medium;
  @override
  Map<String, dynamic> get details => {'method': loginMethod};
}

class AuthLogoutEvent extends AppEvent {
  final String flow;

  const AuthLogoutEvent({
    required super.timestamp,
    super.userId,
    super.tenantId,
    super.deviceId,
    this.flow = 'manual',
  });

  @override
  String get activityType => 'auth.logout';
  @override
  EventCategory get category => EventCategory.auth;
  @override
  Map<String, dynamic> get details => {'flow': flow};
}

class AuthAccessDeniedEvent extends AppEvent {
  final String reason;

  const AuthAccessDeniedEvent({
    required super.timestamp,
    super.userId,
    super.tenantId,
    super.deviceId,
    required this.reason,
  });

  @override
  String get activityType => 'auth.access_denied';
  @override
  EventCategory get category => EventCategory.auth;
  @override
  EventRiskLevel get riskLevel => EventRiskLevel.high;
  @override
  Map<String, dynamic> get details => {'reason': reason};
}

class AuthDeviceBindEvent extends AppEvent {
  final String bindDeviceId;

  const AuthDeviceBindEvent({
    required super.timestamp,
    super.userId,
    super.tenantId,
    super.deviceId,
    required this.bindDeviceId,
  });

  @override
  String get activityType => 'auth.device_bind';
  @override
  EventCategory get category => EventCategory.auth;
  @override
  EventRiskLevel get riskLevel => EventRiskLevel.medium;
  @override
  String get entityId => bindDeviceId;
  @override
  Map<String, dynamic> get details => {'bind_device_id': bindDeviceId};
}

// ─── Course Events ──────────────────────────────────────────────────────────

class CourseOpenedEvent extends AppEvent {
  final String courseId;
  final String courseTitle;

  const CourseOpenedEvent({
    required super.timestamp,
    super.userId,
    super.tenantId,
    super.deviceId,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  String get activityType => 'course.opened';
  @override
  EventCategory get category => EventCategory.course;
  @override
  String get entityId => courseId;
  @override
  Map<String, dynamic> get details => {
    'course_id': courseId,
    'course_title': courseTitle,
  };
}

class CourseEnrolledEvent extends AppEvent {
  final String courseId;

  const CourseEnrolledEvent({
    required super.timestamp,
    super.userId,
    super.tenantId,
    super.deviceId,
    required this.courseId,
  });

  @override
  String get activityType => 'course.enrolled';
  @override
  EventCategory get category => EventCategory.course;
  @override
  String get entityId => courseId;
  @override
  Map<String, dynamic> get details => {'course_id': courseId};
}

class LessonStartedEvent extends AppEvent {
  final String lessonId;
  final String courseId;

  const LessonStartedEvent({
    required super.timestamp,
    super.userId,
    super.tenantId,
    super.deviceId,
    required this.lessonId,
    required this.courseId,
  });

  @override
  String get activityType => 'lesson.started';
  @override
  EventCategory get category => EventCategory.course;
  @override
  String get entityId => lessonId;
  @override
  Map<String, dynamic> get details => {
    'lesson_id': lessonId,
    'course_id': courseId,
  };
}

class LessonCompletedEvent extends AppEvent {
  final String lessonId;
  final String courseId;

  const LessonCompletedEvent({
    required super.timestamp,
    super.userId,
    super.tenantId,
    super.deviceId,
    required this.lessonId,
    required this.courseId,
  });

  @override
  String get activityType => 'lesson.completed';
  @override
  EventCategory get category => EventCategory.course;
  @override
  String get entityId => lessonId;
  @override
  Map<String, dynamic> get details => {
    'lesson_id': lessonId,
    'course_id': courseId,
  };
}

// ─── Video Events ───────────────────────────────────────────────────────────

class VideoStartedEvent extends AppEvent {
  final String lessonId;

  const VideoStartedEvent({
    required super.timestamp,
    super.userId,
    super.tenantId,
    super.deviceId,
    required this.lessonId,
  });

  @override
  String get activityType => 'video.started';
  @override
  EventCategory get category => EventCategory.video;
  @override
  String get entityId => lessonId;
  @override
  Map<String, dynamic> get details => {'lesson_id': lessonId};
}

class VideoCompletedEvent extends AppEvent {
  final String lessonId;
  final int watchTimeSec;

  const VideoCompletedEvent({
    required super.timestamp,
    super.userId,
    super.tenantId,
    super.deviceId,
    required this.lessonId,
    required this.watchTimeSec,
  });

  @override
  String get activityType => 'video.completed';
  @override
  EventCategory get category => EventCategory.video;
  @override
  String get entityId => lessonId;
  @override
  Map<String, dynamic> get details => {
    'lesson_id': lessonId,
    'watch_time_sec': watchTimeSec,
  };
}

// ─── Offline Download / Playback Security Events ───────────────────────────
//
// P6.36/P6.37 of
// EduZone_Offline_Download_Security_Trusted_Playback_Architecture.md
// requires security telemetry for the offline entitlement/playback
// lifecycle (download.authorized, download.failed, playback.denied, ...)
// without ever logging keys, tokens, signed URLs, or file paths. These
// events only carry a `downloadId`/`reason` — never the fields
// [AppEvent.details] must not include, per project instructions §15.

/// Emitted by [OfflinePolicyEngine.authorize] every time offline playback
/// is denied, tagged with the machine-readable
/// `OfflinePlaybackDenialReason`. Deliberately [EventRiskLevel.high] so it
/// is always routed to the encrypted audit path (`AuditHandler`) rather
/// than the plain activity log, since a denial can indicate tampering,
/// device/account mismatch, or a revoked/expired entitlement.
class OfflinePlaybackDeniedEvent extends AppEvent {
  final String downloadId;
  final String reason;

  const OfflinePlaybackDeniedEvent({
    required super.timestamp,
    super.userId,
    super.tenantId,
    super.deviceId,
    required this.downloadId,
    required this.reason,
  });

  @override
  String get activityType => 'offline_download.playback_denied';
  @override
  EventCategory get category => EventCategory.download;
  @override
  EventRiskLevel get riskLevel => EventRiskLevel.high;
  @override
  String get entityId => downloadId;
  @override
  Map<String, dynamic> get details => {'reason': reason};
}

/// Emitted once offline playback for [downloadId] has passed every check
/// in [OfflinePolicyEngine.authorize] and is about to start.
class OfflinePlaybackAuthorizedEvent extends AppEvent {
  final String downloadId;

  const OfflinePlaybackAuthorizedEvent({
    required super.timestamp,
    super.userId,
    super.tenantId,
    super.deviceId,
    required this.downloadId,
  });

  @override
  String get activityType => 'offline_download.playback_authorized';
  @override
  EventCategory get category => EventCategory.download;
  @override
  String get entityId => downloadId;
}

/// Emitted when [DownloadExecutionService.execute] terminates in the
/// `catch` branch — i.e. a download actually failed, as opposed to being
/// paused or cancelled (both handled separately and never reach here).
///
/// Previously this class of failure (network error, disk-full, corrupt
/// chunk, storage-quota rejection, or anything else `execute()`'s
/// try/catch could see) was reported nowhere but a `kDebugMode`-only
/// `debugPrint` — no Sentry, no audit trail, no way to see download
/// failure rates in production at all. [reason] is a coarse,
/// machine-readable classification (`'storage_full'`, `'network'`,
/// `'unknown'` — see `_classifyDownloadFailure` in
/// `download_execution_service.dart`), deliberately not the raw
/// exception text, to keep this event's `details` free of paths/URLs by
/// construction rather than by remembering to scrub them at each call
/// site — the same discipline `OfflinePlaybackDeniedEvent.reason` above
/// already follows.
class DownloadFailedEvent extends AppEvent {
  final String downloadId;
  final String reason;

  const DownloadFailedEvent({
    required super.timestamp,
    super.userId,
    super.tenantId,
    super.deviceId,
    required this.downloadId,
    required this.reason,
  });

  @override
  String get activityType => 'offline_download.download_failed';
  @override
  EventCategory get category => EventCategory.download;
  @override
  EventRiskLevel get riskLevel => EventRiskLevel.medium;
  @override
  String get entityId => downloadId;
  @override
  Map<String, dynamic> get details => {'reason': reason};
}

// ─── Todo Events ────────────────────────────────────────────────────────────

class TodoCreatedEvent extends AppEvent {
  final String todoId;

  const TodoCreatedEvent({
    required super.timestamp,
    super.userId,
    super.tenantId,
    super.deviceId,
    required this.todoId,
  });

  @override
  String get activityType => 'todo.created';
  @override
  EventCategory get category => EventCategory.todo;
  @override
  String get entityId => todoId;
  @override
  Map<String, dynamic> get details => {'todo_id': todoId};
}

class TodoCompletedEvent extends AppEvent {
  final String todoId;

  const TodoCompletedEvent({
    required super.timestamp,
    super.userId,
    super.tenantId,
    super.deviceId,
    required this.todoId,
  });

  @override
  String get activityType => 'todo.completed';
  @override
  EventCategory get category => EventCategory.todo;
  @override
  String get entityId => todoId;
  @override
  Map<String, dynamic> get details => {'todo_id': todoId};
}

// ─── Navigation Events ──────────────────────────────────────────────────────

class ScreenViewedEvent extends AppEvent {
  final String screenName;

  const ScreenViewedEvent({
    required super.timestamp,
    super.userId,
    super.tenantId,
    super.deviceId,
    required this.screenName,
  });

  @override
  String get activityType => 'navigation.screen_viewed';
  @override
  EventCategory get category => EventCategory.navigation;
  @override
  String get entityId => screenName;
  @override
  Map<String, dynamic> get details => {'screen': screenName};
}

class TabSwitchedEvent extends AppEvent {
  final String tabName;

  const TabSwitchedEvent({
    required super.timestamp,
    super.userId,
    super.tenantId,
    super.deviceId,
    required this.tabName,
  });

  @override
  String get activityType => 'navigation.tab_switched';
  @override
  EventCategory get category => EventCategory.navigation;
  @override
  String get entityId => tabName;
  @override
  Map<String, dynamic> get details => {'tab': tabName};
}

// ─── System Events ──────────────────────────────────────────────────────────

class AppOpenedEvent extends AppEvent {
  const AppOpenedEvent({
    required super.timestamp,
    super.userId,
    super.tenantId,
    super.deviceId,
  });

  @override
  String get activityType => 'system.app_opened';
  @override
  EventCategory get category => EventCategory.system;
}

class AppBackgroundedEvent extends AppEvent {
  const AppBackgroundedEvent({
    required super.timestamp,
    super.userId,
    super.tenantId,
    super.deviceId,
  });

  @override
  String get activityType => 'system.app_backgrounded';
  @override
  EventCategory get category => EventCategory.system;
}

class ErrorOccurredEvent extends AppEvent {
  final String errorMessage;
  final String? stackTrace;

  const ErrorOccurredEvent({
    required super.timestamp,
    super.userId,
    super.tenantId,
    super.deviceId,
    required this.errorMessage,
    this.stackTrace,
  });

  @override
  String get activityType => 'system.error';
  @override
  EventCategory get category => EventCategory.system;
  @override
  EventRiskLevel get riskLevel => EventRiskLevel.high;
  @override
  Map<String, dynamic> get details => {
    'error': errorMessage,
    if (stackTrace != null) 'stack_trace': stackTrace,
  };
}

// ─── System Metrics (Self-Observability) ─────────────────────────────────────

class SystemMetricsEvent extends AppEvent {
  final int queueSize;
  final int deadLetterSize;
  final double flushSuccessRate;
  final int avgFlushLatencyMs;

  const SystemMetricsEvent({
    required super.timestamp,
    super.userId,
    super.tenantId,
    required this.queueSize,
    required this.deadLetterSize,
    required this.flushSuccessRate,
    required this.avgFlushLatencyMs,
  });

  @override
  String get activityType => 'system.metrics';
  @override
  EventCategory get category => EventCategory.system;
  @override
  Map<String, dynamic> get details => {
    'queue_size': queueSize,
    'dead_letter_size': deadLetterSize,
    'flush_success_rate': flushSuccessRate,
    'avg_flush_latency_ms': avgFlushLatencyMs,
  };
}
