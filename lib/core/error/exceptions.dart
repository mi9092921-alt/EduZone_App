/// Typed exception hierarchy for the EduZone app.
///
/// Each variant maps to a specific Supabase/RPC error code
/// and carries a user-facing message key for localization.
sealed class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => 'AppException($code): $message';
}

/// Invalid email or password.
class InvalidCredentialsException extends AppException {
  const InvalidCredentialsException()
    : super('Invalid credentials', code: 'invalid_credentials');
}

/// Account has reached maximum device limit (1 device).
class MaxDevicesReachedException extends AppException {
  const MaxDevicesReachedException()
    : super('Maximum devices reached', code: 'MAX_DEVICES_REACHED');
}

/// This device is already bound to a different account.
class DeviceAlreadyBoundException extends AppException {
  const DeviceAlreadyBoundException()
    : super(
        'Device already bound to another account',
        code: 'DEVICE_ALREADY_BOUND',
      );
}

/// Too many login attempts — must wait before retrying.
class RateLimitedException extends AppException {
  final int retryAfterSeconds;

  const RateLimitedException({this.retryAfterSeconds = 300})
    : super('Rate limited', code: 'RATE_LIMITED');
}

/// No internet connection.
class NoInternetException extends AppException {
  const NoInternetException()
    : super('No internet connection', code: 'network_error');
}

/// User is not authenticated — session expired or missing.
class UnauthenticatedException extends AppException {
  const UnauthenticatedException()
    : super('Authentication required', code: 'AUTH_REQUIRED');
}

class ServerException extends AppException {
  const ServerException([super.message = 'Server error'])
    : super(code: 'server_error');
}

/// Device not found for current user — forced logout.
class DeviceNotFoundException extends AppException {
  const DeviceNotFoundException()
    : super('Device not registered', code: 'DEVICE_NOT_FOUND');
}
/// Email not confirmed in Supabase.
class EmailNotConfirmedException extends AppException {
  const EmailNotConfirmedException()
    : super('Email not confirmed', code: 'email_not_confirmed');
}
