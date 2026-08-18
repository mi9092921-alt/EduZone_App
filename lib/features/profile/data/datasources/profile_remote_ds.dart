import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/network_config.dart';
import '../../../../core/network/network_exception_mapper.dart';
import '../../../../core/network/network_guard.dart';
import '../../../../core/network/supabase_client.dart';
import '../../domain/entities/student_profile.dart';

/// Remote data source for profile operations via Supabase.
///
/// All queries are scoped to the authenticated user via RLS.
///
/// Previously had no error handling at all -- any failure (including a
/// bare `SocketException`/no-timeout hang) propagated straight out of
/// Supabase's client with no client-side timeout, no classification, and
/// no distinction from a genuine server error. See Section 13
/// ("Networking Reliability") of the project instructions.
class ProfileRemoteDataSource {
  /// Fetch current user's profile from `users` table.
  Future<StudentProfile> getProfile() async {
    return NetworkGuard.read(() async {
      try {
        final uid = SupabaseService.client.auth.currentUser!.id;

        final response = await SupabaseService.client
            .from('users')
            .select()
            .eq('id', uid)
            .single();

        return StudentProfile.fromJson(response);
      } on PostgrestException catch (e) {
        throw ServerException(e.message, e.code); // check-ignore
      } catch (e) {
        if (e is AppException) rethrow;
        throw NetworkExceptionMapper.map(e);
      }
    });
  }

  /// Update user profile fields. Only non-null params are sent.
  Future<StudentProfile> updateProfile({
    String? firstName,
    String? lastName,
  }) async {
    return NetworkGuard.write(() async {
      try {
        final uid = SupabaseService.client.auth.currentUser!.id;
        final updates = <String, dynamic>{};

        if (firstName != null) updates['first_name'] = firstName;
        if (lastName != null) updates['last_name'] = lastName;

        if (updates.isEmpty) return getProfile();

        final response = await SupabaseService.client
            .from('users')
            .update(updates)
            .eq('id', uid)
            .select()
            .single();

        return StudentProfile.fromJson(response);
      } on PostgrestException catch (e) {
        throw ServerException(e.message, e.code); // check-ignore
      } catch (e) {
        if (e is AppException) rethrow;
        throw NetworkExceptionMapper.map(e);
      }
    });
  }

  /// Upload avatar image to Supabase Storage.
  ///
  /// Uploads to `avatars/{uid}/avatar.jpg` with upsert,
  /// then updates `users.avatar_url` with the public URL.
  /// Returns the public URL.
  Future<String> uploadAvatar(String filePath) async {
    // Uses `heavyTimeout` (not the default write timeout) because this
    // is a file upload, not a small row mutation, and a generous mobile
    // upload can legitimately take longer than a plain `update`.
    return NetworkGuard.write(
      () async {
        try {
          final uid = SupabaseService.client.auth.currentUser!.id;
          final file = File(filePath);
          final storagePath = '$uid/avatar.jpg';

          // Upload with upsert to replace existing avatar
          await SupabaseService.client.storage
              .from('avatars')
              .upload(
                storagePath,
                file,
                fileOptions: const FileOptions(
                  upsert: true,
                  contentType: 'image/jpeg',
                ),
              );

          // Get public URL
          final publicUrl = SupabaseService.client.storage
              .from('avatars')
              .getPublicUrl(storagePath);

          // Update user record with new avatar URL
          await SupabaseService.client
              .from('users')
              .update({'avatar_url': publicUrl})
              .eq('id', uid);

          return publicUrl;
        } on StorageException catch (e) {
          throw ServerException(e.message, e.statusCode); // check-ignore
        } on PostgrestException catch (e) {
          throw ServerException(e.message, e.code); // check-ignore
        } catch (e) {
          if (e is AppException) rethrow;
          throw NetworkExceptionMapper.map(e);
        }
      },
      timeout: NetworkConfig.heavyTimeout,
    );
  }
}
