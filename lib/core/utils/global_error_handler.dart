import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../design_system/design_system.dart';
import '../error/exceptions.dart';
import '../l10n/arb/app_localizations.dart';
import '../network/network_exception_mapper.dart';

/// Centralized error management system for the EduZone app.
///
/// Handles logging, crash reporting via Sentry, and provides
/// diagnostic data for developers.
class GlobalErrorHandler {
  GlobalErrorHandler._();

  static void init() {
    // 1. Capture Flutter framework errors (Widget building, etc.)
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      logError(details.exception, details.stack);
    };

    // 2. Capture platform/async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      logError(error, stack);
      return true;
    };
  }

  /// Whether [error] is an expected, non-actionable connectivity failure
  /// that must never be reported to Sentry as a production "error" event.
  ///
  /// Extracted as its own pure, `@visibleForTesting` method (mirroring
  /// `AuthErrorPolicy.isTransient`) because [logError] is the *sole*
  /// funnel for uncaught Flutter framework/platform-level errors (see
  /// [init]) -- unlike every other call site in the app, which already
  /// classifies via [NetworkExceptionMapper] before deciding whether to
  /// report -- so this funnel's own classification decision needs to be
  /// independently testable without a live/mocked Sentry Hub.
  ///
  /// This mirrors CHECKUSERACCESS-BUG-01
  /// (`check_student_app_access_service.dart`): a device with no connectivity
  /// makes *every* Supabase call fail with a DNS/socket-level error. That
  /// fix only covered the `check_student_app_access` RPC's own catch block.
  /// Supabase's own *internal* background token auto-refresh timer
  /// (`GoTrueClient._callRefreshToken`) throws the same class of error on
  /// its own, uncaught by app code, so it surfaces here via
  /// `PlatformDispatcher.instance.onError` instead and needs the same
  /// treatment applied at this funnel too -- otherwise every DNS blip
  /// while a session's background refresh timer happens to fire becomes
  /// a recurring "error"-level Sentry event indistinguishable from a
  /// genuine crash (Section 15: Sentry must stay useful, not just
  /// complete).
  @visibleForTesting
  static bool isConnectivityNoise(Object error) {
    final classified = NetworkExceptionMapper.map(error);
    return classified is NoInternetException ||
        classified is RequestTimeoutException;
  }

  /// Logs errors to the console and forwards non-connectivity errors to
  /// Sentry.
  static void logError(Object error, StackTrace? stack) {
    final isConnectivity = isConnectivityNoise(error);

    // This is the single funnel for every uncaught Flutter/platform error
    // in the app (see [init] below), so `error` can be anything --
    // including a PostgrestException/DioException whose message embeds
    // backend internals or a full request URL (which, for a signed
    // download URL, can carry an auth token in the query string; see
    // the offline-security architecture's P6.26 "Secure Temporary URLs"
    // requirement not to keep those in logs). `debugPrint` is NOT
    // release-gated by Flutter -- it prints in release builds too -- so
    // printing `error`/`stack` unconditionally would leak that content
    // to the device console/logcat in production (Section 15: "Do not
    // log ... raw sensitive backend payloads"). Sentry (below) remains
    // the full, controlled diagnostic channel; the local console only
    // ever gets the safe exception *type*, matching the pattern already
    // used elsewhere in this codebase (e.g. fcm_service.dart).
    if (kDebugMode) {
      debugPrint('--- [EduZone Error Log] ---');
      debugPrint('Error type: ${error.runtimeType}');
      debugPrint('Error: $error');
      if (stack != null) {
        debugPrint('StackTrace: \n$stack');
      }
      if (isConnectivity) {
        debugPrint('(connectivity failure — not reported to Sentry)');
      }
      debugPrint('---------------------------');
    } else {
      debugPrint(
        '[EduZone] Unhandled error: ${error.runtimeType}'
        '${isConnectivity ? ' (connectivity — not reported to Sentry)' : ''}',
      );
    }

    if (isConnectivity) return;

    // Forward to Sentry (no-op if SDK not initialized / DSN empty)
    try {
      Sentry.captureException(error, stackTrace: stack);
    } catch (_) {
      // Sentry not initialized (e.g. in tests) — swallow silently.
    }
  }
}

/// A premium, user-friendly error screen that replaces the "Red Screen of Death".
///
/// Self-containment boundary: this is the last-resort UI shown when the app
/// has already crashed, so it must not touch app-level SERVICES (no
/// Supabase, no Riverpod providers, no repositories) — anything that could
/// itself be the cause of the crash. Design-system tokens and the l10n
/// delegates are pure, generated, dependency-free lookups and stay safe to
/// use (AppSpacing was already in use here before the localization pass).
///
/// The screen builds its OWN MaterialApp: ErrorWidget.builder can fire
/// outside the real app's MaterialApp (bootstrap crash, crash above the
/// navigator), so the ambient context cannot be relied on for locale or
/// delegates. Wiring the delegates + the DEVICE locale here localizes the
/// screen — the first version hardcoded Arabic copy, which English-locale
/// users saw verbatim.
class AppProductionErrorScreen extends StatelessWidget {
  final FlutterErrorDetails details;

  const AppProductionErrorScreen({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Explicit locale from the BINDING's platformDispatcher (not the raw
      // PlatformDispatcher.instance static): in production both are the
      // device locale, but the binding indirection honors the widget-test
      // localeTestValue seam, and MaterialApp's implicit view-based
      // resolution bypasses the test proxy.
      locale: WidgetsBinding.instance.platformDispatcher.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: _ProductionErrorBody(details: details),
    );
  }
}

/// The localized content of [AppProductionErrorScreen].
///
/// Separate widget so its build context sits UNDER the screen's own
/// MaterialApp and `AppLocalizations.of(context)` actually resolves (the
/// outer widget's context is above the MaterialApp it returns).
class _ProductionErrorBody extends StatelessWidget {
  final FlutterErrorDetails details;

  const _ProductionErrorBody({required this.details});

  @override
  Widget build(BuildContext context) {
    // Null-aware lookup + English fallback: with the delegates wired the
    // lookup always resolves, but this keeps the screen renderable even in
    // a pathological environment where localization itself fails.
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.neutral0,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.monitor_heart_rounded,
                size: 80,
                color: AppColors.error,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                // Crash-screen defensive fallback: rendered only when
                // localization itself fails to resolve.
                l10n?.errorScreenTitle ?? 'Something went wrong', // check-ignore
                style: AppTextStyles.h2.copyWith(color: AppColors.neutral800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                // Crash-screen defensive fallback: rendered only when
                // localization itself fails to resolve.
                l10n?.errorScreenBody ??
                    "Don't worry, our technical team is already working " // check-ignore
                        'on fixing this. Please try again.', // check-ignore
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.neutral600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl2),
              if (kDebugMode)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      details.exceptionAsString(),
                      style: AppTextStyles.code.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
