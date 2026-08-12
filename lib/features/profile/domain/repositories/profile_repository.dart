import '../entities/student_profile.dart';

/// Abstract repository interface for profile operations.
///
/// Implemented by [ProfileRepositoryImpl] in the data layer.
/// All methods throw typed exceptions on failure.
abstract class ProfileRepository {
  /// Fetch the current authenticated user's profile.
  Future<StudentProfile> getProfile();

  /// Update profile fields. Only non-null params are updated.
  Future<StudentProfile> updateProfile({
    String? firstName,
    String? lastName,
  });

  /// Upload avatar image from local file path.
  /// Returns the public URL of the uploaded avatar.
  Future<String> uploadAvatar(String filePath);
}
