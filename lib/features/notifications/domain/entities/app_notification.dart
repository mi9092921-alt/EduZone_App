import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_notification.freezed.dart';
part 'app_notification.g.dart';

@freezed
abstract class AppNotification with _$AppNotification {
  const AppNotification._();

  const factory AppNotification({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'notification_id') String? notificationId,
    @JsonKey(name: 'is_read') @Default(false) bool isRead,
    @JsonKey(name: 'read_at') DateTime? readAt,
    @JsonKey(name: 'tenant_id') required String tenantId,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    
    /// Nested notification details from the `notifications` table.
    /// This is populated via a join in the remote data source.
    @JsonKey(name: 'notification') NotificationDetails? details,
  }) = _AppNotification;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);

  /// Helper to get title from nested details
  String get title => details?.title ?? 'No Title';

  /// Helper to get body from nested details
  String get body => details?.body ?? 'No Content';

  /// Factory for skeleton dummy data
  factory AppNotification.skeleton() => AppNotification(
        id: 'skeleton',
        userId: 'skeleton',
        tenantId: 'skeleton',
        createdAt: DateTime.now(),
        details: const NotificationDetails(
          title: 'Loading Notification Title...',
          body: 'This is the loading notification body content...',
        ),
      );
}

@freezed
abstract class NotificationDetails with _$NotificationDetails {
  const factory NotificationDetails({
    required String title,
    required String body,
  }) = _NotificationDetails;

  factory NotificationDetails.fromJson(Map<String, dynamic> json) =>
      _$NotificationDetailsFromJson(json);
}
