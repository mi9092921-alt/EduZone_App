import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../constants/app_constants.dart';

/// Centralized Sentry SDK initialization and context management.
///
/// Follows the same singleton-service pattern as [SupabaseService].
/// If the DSN is empty (e.g. local dev without a DSN configured),
/// Sentry silently becomes a no-op — no errors are thrown.
class SentryService {
  SentryService._();

  /// Whether Sentry was successfully initialized with a valid DSN.
  static bool _initialized = false;

  /// Returns `true` if Sentry is actively capturing events.
  static bool get isInitialized => _initialized;

  /// Initializes `SentryFlutter` with the DSN from environment.
  ///
  /// Must be called as the outermost wrapper in `main()` because
  /// `SentryFlutter.init` creates its own `runZonedGuarded` to
  /// capture uncaught async errors.
  ///
  /// [appRunner] is the callback that runs the rest of the app
  /// bootstrap (binding, services, `runApp`).
  static Future<void> initialize({
    required Future<void> Function() appRunner,
  }) async {
    const dsn = AppConstants.sentryDsn;

    if (dsn.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[SentryService] SENTRY_DSN is empty — '
          'Sentry disabled for this session.',
        );
      }
      // Run the app without Sentry wrapping.
      await appRunner();
      return;
    }

    await SentryFlutter.init(
      (options) {
        options.dsn = dsn;
        options.environment = AppConstants.appEnv;

        // Full tracing in dev, conservative in production.
        options.tracesSampleRate =
            AppConstants.appEnv == 'production' ? 0.2 : 1.0;

        // Attach screenshots on crashes (release builds only).
        options.attachScreenshot = !kDebugMode;

        // Don't send PII automatically — we control user context
        // explicitly via [setUserContext].
        options.sendDefaultPii = false;

        // Debug logging in dev only.
        if (kDebugMode) {
          options.debug = true;
        }
      },
      appRunner: appRunner,
    );

    _initialized = true;
  }

  /// Attaches the authenticated student's UUID to all Sentry events.
  ///
  /// Call after successful login. Only the opaque UUID is sent —
  /// no email, name, or other PII.
  static void setUserContext(String userId) {
    if (!_initialized) return;
    Sentry.configureScope(
      (scope) => scope.setUser(SentryUser(id: userId)),
    );
  }

  /// Clears user context on sign-out.
  static void clearUserContext() {
    if (!_initialized) return;
    Sentry.configureScope((scope) => scope.setUser(null));
  }
}
