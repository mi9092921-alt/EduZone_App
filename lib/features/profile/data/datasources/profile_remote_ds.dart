import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client.dart';
import '../../domain/entities/student_profile.dart';

/// Remote data source for profile operations via Supabase.
///
/// All queries are scoped to the authenticated user via RLS.
class ProfileRemoteDataSource {
  /// Fetch current user's profile from `users` table.
  Future<StudentProfile> getProfile() async {
    final uid = SupabaseService.client.auth.currentUser!.id;

    final response = await SupabaseService.client
        .from('users')
        .select()
        .eq('id', uid)
        .single();

    return StudentProfile.fromJson(response);
  }

  /// Update user profile fields. Only non-null params are sent.
  Future<StudentProfile> updateProfile({
    String? firstName,
    String? lastName,
  }) async {
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
  }

  /// Upload avatar image to Supabase Storage.
  ///
  /// Uploads to `avatars/{uid}/avatar.jpg` with upsert,
  /// then updates `users.avatar_url` with the public URL.
  /// Returns the public URL.
  Future<String> uploadAvatar(String filePath) async {
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
  }
}
