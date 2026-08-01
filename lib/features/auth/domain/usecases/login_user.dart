import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

class LoginUser {
  final AuthRepository repository;

  LoginUser(this.repository);

  Future<AppUser> call(String email, String password) {
    return repository.login(email, password);
  }
}
