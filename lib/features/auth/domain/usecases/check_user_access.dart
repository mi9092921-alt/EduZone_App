import '../entities/user_access.dart';
import '../repositories/auth_repository.dart';

/// Calls `check_user_access()` RPC to determine current account status.
class CheckUserAccess {
  final AuthRepository repository;

  CheckUserAccess(this.repository);

  Future<UserAccess> call() {
    return repository.checkUserAccess();
  }
}
