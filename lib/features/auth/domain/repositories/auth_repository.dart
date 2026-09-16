import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/user_access.dart';
import '../entities/bind_device_result.dart';

/// Auth repository contract — defines all authentication operations.
///
/// Implementation lives in the data layer (`AuthRepositoryImpl`).
/// Domain use cases depend only on this interface.
abstract class AuthRepository {
  /// Check current user's access status via RPC `check_student_app_access()`.
  Future<UserAccess> checkStudentAppAccess();

  /// Sign in with email + password against Supabase Auth only.
  /// The profile must be fetched after the app access check.
  Future<void> login(String email, String password);

  /// Bind the current device to the authenticated user.
  Future<BindDeviceResult> bindDevice(
    String deviceId,
    Map<String, dynamic> deviceInfo,
    String platform,
  );

  /// Log out — calls `logout_current_user()` RPC + `auth.signOut()`.
  Future<void> logout();

  /// Check if a specific device fingerprint is registered for a user.
  Future<bool> validateDeviceExists(String userId, String fingerprint);

  /// Get the currently authenticated user, or null if not signed in.
  Future<AppUser?> getCurrentUser();
}
