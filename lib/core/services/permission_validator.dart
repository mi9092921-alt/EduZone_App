import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for validating offline access permissions.
///
/// Checks user enrollment status, subscription expiry, and download expiration
/// before allowing offline playback of downloaded videos.
class PermissionValidator {
  final SupabaseClient _client;

  PermissionValidator(this._client);

  /// Validates if the user can play a lesson offline.
  ///
  /// Returns true if:
  /// - User is enrolled in the course
  /// - Subscription is active
  /// - Download has not expired
  Future<bool> canPlayOffline(String lessonId) async {
    try {
      // Check enrollment via Supabase RPC
      final response = await _client.rpc('validate_offline_access', params: {
        'p_lesson_id': lessonId,
      });

      return response as bool? ?? false;
    } catch (e) {
      // If offline check fails, deny access for safety
      return false;
    }
  }

  /// Validates if the user has access to a course.
  ///
  /// Checks enrollment status and subscription validity.
  Future<bool> validateAccess(String courseId) async {
    try {
      final response = await _client.rpc('validate_course_access', params: {
        'p_course_id': courseId,
      });

      return response as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Gets the subscription expiry date for the current user.
  ///
  /// Returns null if no subscription or if check fails.
  Future<DateTime?> getSubscriptionExpiry() async {
    try {
      final response = await _client.rpc('get_subscription_expiry');
      
      if (response == null) return null;
      
      return DateTime.parse(response as String);
    } catch (e) {
      return null;
    }
  }

  /// Checks if the user's subscription is active.
  Future<bool> isSubscriptionActive() async {
    final expiry = await getSubscriptionExpiry();
    if (expiry == null) return false;
    
    return DateTime.now().isBefore(expiry);
  }

  /// Checks if a download has expired based on its expiration date.
  bool isDownloadExpired(DateTime expiresAt) {
    return DateTime.now().isAfter(expiresAt);
  }
}
