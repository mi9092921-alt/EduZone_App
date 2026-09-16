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

/// A network-bound operation (Postgrest/RPC/Auth/Storage call) did not
/// complete within the client-side timeout budget (see
/// `NetworkConfig`). Distinct from [NoInternetException] -- the device
/// may well have connectivity, but the server/edge/CDN did not respond
/// in time (slow network, congested endpoint, stalled TLS handshake).
/// Kept as its own type (rather than folded into [ServerException]) so
/// [NetworkRetry] can tell "worth retrying" apart from a definite server
/// error without string-matching the message.
class RequestTimeoutException extends AppException {
  const RequestTimeoutException()
    : super('Request timed out', code: 'request_timeout'); // check-ignore
}

/// User is not authenticated — session expired or missing.
class UnauthenticatedException extends AppException {
  const UnauthenticatedException()
    : super('Authentication required', code: 'AUTH_REQUIRED');
}

/// The server revoked a session that WAS active mid-flight: a non-auth RPC
/// (courses, downloads, telemetry, ...) rejected the call with Postgres
/// ERRCODE 28000 ("invalid authorization") or the project's AUTH_REQUIRED
/// business error because the account's token_version was bumped, the
/// session row was deactivated server-side, or the device binding was
/// revoked.
///
/// Distinct from [UnauthenticatedException] ("there is no session to use"):
/// this asserts the server actively killed a live session, so the client
/// must force a sign-out instead of silently retrying or surfacing a
/// generic server error. Classification lives in
/// `NetworkExceptionMapper.map`; the forced-sign-out reaction is wired via
/// `SessionRevocationHook` (auth_provider registers the handler).
class SessionRevokedException extends AppException {
  const SessionRevokedException()
    : super('Session revoked by server', code: 'SESSION_REVOKED');
}

class ServerException extends AppException {
  const ServerException([super.message = 'Server error', String? errorCode]) // check-ignore
    : super(code: errorCode ?? 'server_error');
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
