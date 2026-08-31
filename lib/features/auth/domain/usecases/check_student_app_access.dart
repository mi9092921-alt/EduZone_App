import '../entities/user_access.dart';
import '../repositories/auth_repository.dart';

/// Calls `check_student_app_access()` RPC to determine current account status.
class CheckStudentAppAccess {
  final AuthRepository repository;

  CheckStudentAppAccess(this.repository);

  Future<UserAccess> call() {
    return repository.checkStudentAppAccess();
  }
}
