import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

/// Returns the currently authenticated user, or null if not signed in.
class GetCurrentUser {
  final AuthRepository repository;

  GetCurrentUser(this.repository);

  Future<AppUser?> call() {
    return repository.getCurrentUser();
  }
}