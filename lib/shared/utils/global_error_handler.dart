import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../core/error/exceptions.dart';
import '../../core/network/network_exception_mapper.dart';

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
/// Deliberately does NOT depend on lib/design_system/ tokens: this is the
/// last-resort UI shown when the app has already crashed, possibly due to
/// a bug in app-level code. Keeping it fully self-contained means it can
/// still render even if something elsewhere (theoretically including the
/// design system itself) is what caused the crash. Raw values below are
/// intentional for that reason -- check-ignore is added on the relevant
/// lines rather than wiring in AppSpacing/AppTextStyles/AppColors.
class AppProductionErrorScreen extends StatelessWidget {
  final FlutterErrorDetails details;

  const AppProductionErrorScreen({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0), // check-ignore -- see class doc
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.monitor_heart_rounded,
                  size: 80,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 24),
                const Text( // check-ignore -- see class doc
                  'حدث خطأ غير متوقع',
                  style: TextStyle( // check-ignore -- see class doc
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text( // check-ignore -- see class doc
                  'لا تقلق، فريقنا الفني سيعمل على إصلاح المشكلة في أسرع وقت. يرجى المحاولة مرة أخرى.',
                  style: TextStyle(fontSize: 14, color: Colors.black54), // check-ignore -- see class doc
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (kDebugMode)
                  Container(
                    padding: const EdgeInsets.all(12), // check-ignore -- see class doc
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8), // check-ignore -- see class doc
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        details.exceptionAsString(),
                        style: const TextStyle( // check-ignore -- see class doc
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
