import '../entities/student_profile.dart';
import '../repositories/profile_repository.dart';

/// Use case: Update the authenticated user's profile.
///
/// Validates that at least one field is provided before
/// delegating to [ProfileRepository.updateProfile].
class UpdateProfile {
  final ProfileRepository _repository;

  UpdateProfile(this._repository);

  Future<StudentProfile> call({
    String? firstName,
    String? lastName,
  }) async {
    // Trim whitespace
    final trimmedFirst = firstName?.trim();
    final trimmedLast = lastName?.trim();

    return _repository.updateProfile(
      firstName: trimmedFirst,
      lastName: trimmedLast,
    );
  }

  /// Upload avatar from local file path.
  /// Returns the public URL of the uploaded avatar.
  Future<String> uploadAvatar(String filePath) {
    return _repository.uploadAvatar(filePath);
  }
}
