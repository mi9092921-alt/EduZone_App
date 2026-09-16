// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppNotification _$AppNotificationFromJson(Map<String, dynamic> json) =>
    _AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      notificationId: json['notification_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'] as String),
      tenantId: json['tenant_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      details: json['notification'] == null
          ? null
          : NotificationDetails.fromJson(
              json['notification'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$AppNotificationToJson(_AppNotification instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'notification_id': instance.notificationId,
      'is_read': instance.isRead,
      'read_at': instance.readAt?.toIso8601String(),
      'tenant_id': instance.tenantId,
      'created_at': instance.createdAt.toIso8601String(),
      'notification': instance.details,
    };

_NotificationDetails _$NotificationDetailsFromJson(Map<String, dynamic> json) =>
    _NotificationDetails(
      title: json['title'] as String,
      body: json['body'] as String,
    );

Map<String, dynamic> _$NotificationDetailsToJson(
  _NotificationDetails instance,
) => <String, dynamic>{'title': instance.title, 'body': instance.body};
