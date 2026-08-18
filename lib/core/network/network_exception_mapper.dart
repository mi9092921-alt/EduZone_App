import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../error/exceptions.dart';

/// Central, reusable classifier for exceptions raised by network-bound
/// datasource calls (Supabase Postgrest/RPC/Auth/Storage/Edge Function
/// requests, or the underlying Dart HTTP/socket stack).
///
/// Before this existed, ~10 data sources each had their own
/// `catch (e) { throw ServerException(e.toString()); }` fallback, which
/// meant a genuine connectivity failure (`SocketException`), a
/// client-side timeout, and an actual 5xx from Supabase were all
/// indistinguishable once caught -- both to `ErrorHandler` (so the user
/// always saw the same generic message regardless of whether retrying
/// would help) and to whatever calls this next (so `NetworkRetry` had
/// no reliable signal for "this is a transient network fault, retry it"
/// vs. "this is a real server/business error, don't").
///
/// This mirrors the classification `auth_remote_ds.dart` already does
/// for `AuthRetryableFetchException` (see `_mapAuthException`) but makes
/// it available to every other feature instead of being duplicated --
/// or, more commonly, simply absent.
class NetworkExceptionMapper {
  NetworkExceptionMapper._();

  /// Maps a raw caught error to an [AppException].
  static AppException map(Object error) {
    // Already a typed, deliberately-thrown business error (e.g.
    // MaxDevicesReachedException raised by a caller upstream) -- must
    // never be re-wrapped, or callers checking `error is XException`
    // downstream would silently stop matching.
    if (error is AppException) return error;

    if (error is SocketException) {
      return const NoInternetException();
    }

    if (error is TimeoutException) {
      return const RequestTimeoutException();
    }

    if (error is AuthRetryableFetchException) {
      // gotrue throws this both for real connectivity failures
      // (statusCode == null -- the request never reached a server) and
      // for 5xx responses from Supabase's own Auth backend. These are
      // different problems from the user's perspective (retry locally
      // vs. "the service is down"), so they must not collapse into one
      // message. Mirrors `auth_remote_ds.dart`'s `_mapAuthException`.
      return error.statusCode == null
          ? const NoInternetException()
          : const ServerException('Authentication service unavailable', 'auth_service_unavailable'); // check-ignore
    }

    if (error is PostgrestException) {
      // Preserve the real Postgres/RLS error code instead of discarding
      // it -- callers that need to branch on specific codes (RPC
      // business errors like MAX_DEVICES_REACHED) already catch
      // PostgrestException themselves before this mapper runs; this
      // path only handles the ones that fall through unclassified.
      return ServerException(error.message, error.code); // check-ignore
    }

    if (error is StorageException) {
      return ServerException(error.message, error.statusCode); // check-ignore
    }

    if (error is FunctionException) {
      return ServerException(
        'Edge function error ${error.status}', // check-ignore
        error.status.toString(),
      );
    }

    if (error is FormatException) {
      // Malformed/unexpected server payload (e.g. JSON shape changed
      // server-side). Never surface the raw parser message to the user.
      return const ServerException('Malformed server response', 'malformed_response'); // check-ignore
    }

    // Fallback for anything not already classified above -- some
    // platform-level connectivity failures on Android/iOS surface as a
    // plain `Exception`/`HttpException` wrapping a socket error rather
    // than a `SocketException` instance, so string-match a few known,
    // stable substrings as a best-effort second pass before giving up
    // and reporting a generic server error.
    final message = error.toString();
    final lower = message.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('httpexception')) {
      return const NoInternetException();
    }
    if (lower.contains('timeoutexception') || lower.contains('timed out')) {
      return const RequestTimeoutException();
    }

    return ServerException(message); // check-ignore
  }

  /// Whether [error] represents a transient, connectivity-level failure
  /// that is safe to retry for an idempotent read (see `NetworkRetry`).
  /// Business errors (invalid credentials, RLS denial, rate limiting,
  /// not-found, malformed payload, etc.) are deliberately excluded --
  /// retrying those would not fix them and would just delay a failure
  /// the caller needs to see now.
  static bool isRetryable(AppException error) {
    return error is NoInternetException || error is RequestTimeoutException;
  }
}
