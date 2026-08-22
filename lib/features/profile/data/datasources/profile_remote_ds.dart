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

  /// Update user profile fields via the `api_update_profile` RPC.
  ///
  /// Previously this issued `.from('users').update(...)` directly, which
  /// `10_permissions.sql` explicitly blocks for `authenticated`
  /// (`REVOKE UPDATE ON public.users FROM authenticated`, with only
  /// `last_login`/`last_seen_at` re-granted) -- so every profile-name
  /// update silently failed with a Postgres permission-denied error in
  /// production while `flutter test` stayed green, because the mocked
  /// data source in `profile_repo_impl_test.dart` never touches real
  /// RLS/grants. `api_update_profile` is the SECURITY DEFINER RPC that
  /// was already defined in `07_functions.sql` for exactly this
  /// operation but was never called from any Dart file and never had a
  /// matching `GRANT EXECUTE` -- see the accompanying
  /// `supabase/schema/10_permissions.sql` change. See Section 8/9
  /// ("Authorization must ultimately be enforced server-side" /
  /// "the client must never assume hiding a UI element provides
  /// authorization") and Section 13/14 hardening notes elsewhere in this
  /// file.
  ///
  /// The RPC returns `void` (it only performs the `UPDATE`), so on
  /// success this re-fetches the row via [getProfile] to return the
  /// caller's expected `StudentProfile` -- same external contract as
  /// before, only the write path changed.
  Future<StudentProfile> updateProfile({
    String? firstName,
    String? lastName,
  }) async {
    return NetworkGuard.write(() async {
      try {
        if (firstName == null && lastName == null) return getProfile();

        await SupabaseService.client.rpc(
          'api_update_profile',
          params: {
            'p_first_name': ?firstName,
            'p_last_name': ?lastName,
          },
        );

        return getProfile();
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

          // Update user record with new avatar URL via `api_update_profile`
          // -- same RLS/permission constraint as `updateProfile` above: a
          // direct `.from('users').update(...)` here is blocked by
          // `10_permissions.sql` and previously failed silently after a
          // successful (and now orphaned) storage upload. See the
          // `updateProfile` doc comment above for the full root cause.
          await SupabaseService.client.rpc(
            'api_update_profile',
            params: {'p_avatar_url': publicUrl},
          );

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
