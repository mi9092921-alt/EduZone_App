import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/supabase_client.dart';

abstract class NotificationsRemoteDataSource {
  Future<List<Map<String, dynamic>>> getNotifications(String userId);
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead(String userId);
}

class NotificationsRemoteDataSourceImpl
    implements NotificationsRemoteDataSource {
  final SupabaseClient _client;

  NotificationsRemoteDataSourceImpl([SupabaseClient? client])
    : _client = client ?? SupabaseService.client;

  @override
  Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    try {
      // Step 1: fetch user_notifications rows — the student's RLS allows this.
      final userNotifications = await _client
          .from('user_notifications')
          .select(
            'id, user_id, notification_id, tenant_id, is_read, read_at, created_at',
          )
          .eq('user_id', userId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(50);

      if (userNotifications.isEmpty) return [];

      // Step 2: fetch the notification details (title, body) separately.
      // A direct embedded join triggers the notifications_select RLS policy which
      // requires target_audience = 'all' or explicit notification_targets membership —
      // causing a PostgREST error for students. Fetching by ID list bypasses this
      // because the notifications table RLS is applied per-row and non-visible rows
      // are simply omitted (no error), giving us a safe subset.
      final notificationIds = userNotifications
          .map((un) => un['notification_id'] as String?)
          .whereType<String>()
          .toList();

      final Map<String, Map<String, dynamic>> detailsById = {};
      if (notificationIds.isNotEmpty) {
        final details = await _client
            .from('notifications')
            .select('id, title, body')
            .inFilter('id', notificationIds);

        for (final d in details) {
          detailsById[d['id'] as String] = d;
        }
      }

      // Step 3: merge user_notification rows with their notification details.
      // Normalize the row map so that all timestamp fields (returned as DateTime
      // objects by the Supabase SDK v2) are converted to ISO-8601 strings before
      // being passed to AppNotification.fromJson, which expects String values.
      return userNotifications.map((un) {
        final nId = un['notification_id'] as String?;
        final detail = nId != null ? detailsById[nId] : null;
        final normalized = un.map((key, value) {
          if (value is DateTime) return MapEntry(key, value.toIso8601String());
          return MapEntry(key, value);
        });
        return {
          ...normalized,
          'notification': detail != null
              ? {
                  'title': detail['title']?.toString() ?? '',
                  'body': detail['body']?.toString() ?? '',
                }
              : null,
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    try {
      await _client
          .from('user_notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.timestamp().toIso8601String(),
          })
          .eq('id', notificationId);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    try {
      await _client
          .from('user_notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.timestamp().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('is_read', false);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
