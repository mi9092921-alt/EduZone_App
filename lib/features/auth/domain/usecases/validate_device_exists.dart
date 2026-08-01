import '../repositories/auth_repository.dart';

/// Queries the `devices` table to verify a device fingerprint is registered.
class ValidateDeviceExists {
  final AuthRepository repository;

  ValidateDeviceExists(this.repository);

  Future<bool> call(String userId, String fingerprint) {
    return repository.validateDeviceExists(userId, fingerprint);
  }
}
