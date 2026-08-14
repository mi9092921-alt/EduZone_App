import 'package:flutter/material.dart';
import '../../core/error/exceptions.dart';
import '../../core/l10n/arb/app_localizations.dart';
import 'app_snackbar.dart';

class ErrorHandler {
  ErrorHandler._();

  /// Maps an [AppException] to a localized user-friendly message.
  static String getMessage(BuildContext context, Object error) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return error.toString();

    if (error is InvalidCredentialsException) {
      return l10n.errorAuth;
    } else if (error is NoInternetException) {
      return l10n.errorNetwork;
    } else if (error is MaxDevicesReachedException) {
      return l10n.errorMaxDevices;
    } else if (error is DeviceAlreadyBoundException) {
      return l10n.errorDeviceBound;
    } else if (error is RateLimitedException) {
      return l10n.errorRateLimit((error.retryAfterSeconds / 60).ceil());
    } else if (error is UnauthenticatedException) {
      return l10n.errorAuth; // Fallback to auth error
    } else if (error is EmailNotConfirmedException) {
      return l10n.errorEmailNotConfirmed;
    } else if (error is ServerException) {
      // error.message is an internal, English-only diagnostic string set
      // in the data layer (see e.g. auth_remote_ds.dart) -- it's meant
      // for logs/debugging, not translated, and was never designed to be
      // shown to the user directly. Returning it here was a real bug:
      // every caller across the app that catches a server-side failure
      // and displays ErrorHandler.getMessage() (courses, downloads, todo,
      // notifications, auth) would show raw English text to Arabic-locale
      // users. Map to the localized generic key instead, matching how
      // AuthErrorPolicy.mapExceptionToKey already correctly never
      // surfaces that internal message to a user-facing widget.
      return l10n.errorGeneric;
    }

    return l10n.errorGeneric;
  }

  /// Automatically handles an error by showing a localized Snackbar.
  static void handle(BuildContext context, Object error) {
    final message = getMessage(context, error);
    
    FeedbackService.show(
      context,
      message: message,
      type: FeedbackType.error,
      important: true, // Errors are always important
    );
  }
}
