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
      return error.message;
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
