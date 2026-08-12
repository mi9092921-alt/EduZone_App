import 'dart:convert';
import 'package:crypto/crypto.dart' show md5;

// ─── Risk Levels & Categories ────────────────────────────────────────────────

enum EventRiskLevel { low, medium, high, critical }

enum EventCategory { auth, course, video, todo, navigation, system }

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
