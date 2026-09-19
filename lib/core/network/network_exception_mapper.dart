import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../error/exceptions.dart';
import 'session_revocation_hook.dart';

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
    // Datasources pre-convert `PostgrestException` to `ServerException`
    // before this mapper ever sees the error (documented pattern in every
    // feature datasource), which previously meant the session-revocation
    // check below never ran for those calls. Inspect the pre-converted
    // code/message with the same signatures the PostgrestException branch
    // uses, BEFORE the generic AppException early-return swallows it.
    // Note [SessionRevokedException] is a sibling of [ServerException]
    // (both extend [AppException] directly), so a raw revoked exception
    // arriving here falls through to the early-return below without
    // re-notifying the hook.
    if (error is ServerException &&
        _isSessionRevocationSignature(error.code, error.message)) {
      const revoked = SessionRevokedException();
      SessionRevocationHook.notify(revoked);
      return revoked;
    }

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

    if (error is http.ClientException) {
      // package:http's ClientException is the transport-failure mode of the
      // engine under Supabase's REST client: the connection was aborted,
      // dropped, or reset mid-request (e.g. Android errno 103 "Software
      // caused connection abort"). The request never completed, so this is
      // connectivity noise, not a server error — and for NetworkGuard.read
      // it must classify as retryable (Sentry EDUZONE-V reported it as an
      // unclassified ServerException that skipped the read retry path).
      return const NoInternetException();
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
      // Session revocation surfacing from ANY RPC (not just auth ones): the
      // server kills sessions via token_version bumps / session-row
      // deactivation, which non-auth RPCs report as Postgres ERRCODE 28000
      // ("invalid authorization") or the project's AUTH_REQUIRED business
      // error. These must trip the forced sign-out hook instead of
      // collapsing into a generic ServerException — see SessionRevocationHook.
      if (_isSessionRevocationSignature(error.code, error.message)) {
        const revoked = SessionRevokedException();
        SessionRevocationHook.notify(revoked);
        return revoked;
      }
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
        lower.contains('connection abort') ||
        lower.contains('connection closed') ||
        lower.contains('clientexception') ||
        lower.contains('httpexception')) {
      return const NoInternetException();
    }
    if (lower.contains('timeoutexception') || lower.contains('timed out')) {
      return const RequestTimeoutException();
    }

    return ServerException(message); // check-ignore
  }

  /// Whether [code]/[message] carry one of the session-revocation
  /// signatures the server emits when a live session is killed
  /// (Postgres ERRCODE 28000, the project's AUTH_REQUIRED business error,
  /// or an "invalid user session" message). Shared by the
  /// [PostgrestException] branch and the pre-converted [ServerException]
  /// branch so the two can never drift apart.
  static bool _isSessionRevocationSignature(String? code, String message) {
    final lower = message.toLowerCase();
    return code == '28000' ||
        code == 'AUTH_REQUIRED' ||
        lower.contains('invalid user session') ||
        lower.contains('auth_required');
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
