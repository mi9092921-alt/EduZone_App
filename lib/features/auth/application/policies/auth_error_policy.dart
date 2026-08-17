import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../core/error/exceptions.dart';

/// Centralizes the "is this error transient?" and "which localized error
/// key does this exception map to?" decisions that used to live as private
/// methods (`_isTransientAuthError`, `_mapExceptionToKey`) inside the `Auth`
/// notifier in `auth_provider.dart`.
///
/// Extracted so this policy can be unit-tested directly, without going
/// through Riverpod/Supabase mocking — every method here is pure (no
/// side effects, no dependencies besides the exception types themselves).
///
/// See the `Auth` notifier's `_initializeSession()`/`login()`/
/// `verifyAccess()` doc comments for the full rationale of *when* each
/// policy applies; this class only owns the classification logic itself.
abstract final class AuthErrorPolicy {
  /// A transient error means the server did not actually deny access — it
  /// was unreachable (no internet, timeout, socket failure, or a
  /// [ServerException] whose message indicates a network/connection
  /// issue). Callers must NOT force the user out of an authenticated/
  /// restricted state on a network blip.
  static bool isTransient(Object error) {
    if (error is NoInternetException ||
        error is TimeoutException ||
        error is SocketException) {
      return true;
    }

    if (error is ServerException) {
      if (error.code == 'RPC_RLS_RECURSION') {
        return true;
      }

      final message = error.message.toLowerCase();
      return message.contains('network') ||
          message.contains('timeout') ||
          message.contains('connection');
    }

    return false;
  }

  /// Maps a caught exception to the localization key the login screen (or
  /// any other UI) uses to display the right message.
  ///
  /// All typed exceptions are handled explicitly — anything else falls
  /// back to `'errorGeneric'`, and the unclassified runtime type is logged
  /// so it's never lost silently behind the generic key.
  static String mapExceptionToKey(Object e) {
    if (e is InvalidCredentialsException) return 'errorAuth';
    if (e is EmailNotConfirmedException) return 'errorEmailNotConfirmed';
    if (e is NoInternetException) return 'errorNetwork';
    if (e is RateLimitedException) {
      return 'errorRateLimit:${e.retryAfterSeconds}';
    }
    if (e is MaxDevicesReachedException) return 'errorMaxDevices';
    if (e is DeviceAlreadyBoundException) return 'errorDeviceBound';

    // ServerException is a known, typed exception (e.g. user profile not
    // found, DB unreachable, RLS rejection). It always maps to the generic
    // error message — the message itself is an internal diagnostic string
    // and is never shown to the user. Handled explicitly here so it does
    // NOT trigger the "Unmapped exception type" warning below.
    if (e is ServerException) return 'errorGeneric';

    // Never log exception messages here: SDK/backend errors may contain
    // request details or other sensitive diagnostic data. Keep only the
    // runtime type, which is sufficient to classify and monitor the gap.
    debugPrint('[AuthErrorPolicy] Unmapped exception type: ${e.runtimeType}');
    return 'errorGeneric';
  }
}
