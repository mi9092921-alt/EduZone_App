import '../entities/student_profile.dart';
import '../repositories/profile_repository.dart';

/// Use case: Fetch the authenticated user's profile.
///
/// Delegates to [ProfileRepository.getProfile].
class GetProfile {
  final ProfileRepository _repository;

  GetProfile(this._repository);

  Future<StudentProfile> call() => _repository.getProfile();
}
