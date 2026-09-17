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

        // Deliberately NOT enabling `attachScreenshot`. Sentry's screenshot
        // capture renders the current widget tree directly via Flutter's
        // own Skia pipeline (RenderRepaintBoundary), which happens
        // entirely inside the app process and is therefore NOT blocked
        // by ScreenshotGuard's OS-level FLAG_SECURE / iOS
        // preventScreenshotOn() protection (core/security/guards/
        // screenshot_guard.dart) — that only stops the *system*
        // screenshot/recording APIs from capturing the window. A crash
        // during video playback or on the profile/todo screens would
        // silently exfiltrate licensed course content or personal data
        // in a full-resolution image attached to every crash report,
        // directly defeating the screen-protection threat model in
        // Section 11 and violating Section 15 ("Do not log ... sensitive
        // personal data"). Leaving this off is the fail-safe default;
        // do not re-enable without a redaction/allowlist strategy for
        // which screens are safe to capture.
        options.attachScreenshot = false;

        // Don't send PII automatically — we control user context
        // explicitly via [setUserContext].
        options.sendDefaultPii = false;

        // Strip credential material from every event before it leaves the
        // device. Dio/Postgrest exception messages frequently echo the full
        // request URL, and signed download / Supabase URLs carry an auth
        // token in the query string (docs/SECURITY_DESIGN.md P6.26 — the
        // console path in GlobalErrorHandler already sanitizes for this;
        // this closes the same hole for the Sentry transport).
        options.beforeSend = (event, hint) => redactEvent(event);

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

  /// Matches `key=value` pairs whose value is credential material that must
  /// never reach Sentry. Supabase / signed-download endpoints put session
  /// tokens and api keys in the query string, and error messages echo the
  /// full URL back verbatim. (`\x22`/`\x27` are quote chars — a raw
  /// single-quoted Dart string cannot contain a literal `'`.)
  static final RegExp _credentialParamPattern = RegExp(
    r'(token|api[_-]?key|key|password|secret|authorization|signature|sig)'
    r'=(?:[^&\s"\x27]+)',
    caseSensitive: false,
  );

  /// Matches `Bearer <jwt>` style credentials in free text.
  static final RegExp _bearerTokenPattern = RegExp(
    r'Bearer\s+[A-Za-z0-9\-_.+=/]+',
    caseSensitive: false,
  );

  /// Replaces credential material embedded in free text with `***`.
  @visibleForTesting
  static String redactCredentials(String text) {
    final noBearer = text.replaceFirstMapped(
      _bearerTokenPattern,
      (_) => 'Bearer ***',
    );
    return noBearer.replaceAllMapped(
      _credentialParamPattern,
      (m) => '${m.group(1)}=***',
    );
  }

  /// `beforeSend` hook — walks every free-text field the Flutter SDK can
  /// populate (exception values, breadcrumb messages, the formatted message)
  /// and strips credential material before the event is queued for upload.
  ///
  /// Fail-closed by design: if redaction itself throws, the event is dropped
  /// (returning `null` discards it) rather than forwarded unredacted.
  @visibleForTesting
  static SentryEvent? redactEvent(SentryEvent event) {
    try {
      final exceptions = event.exceptions
          ?.map(
            (e) =>
                e.value == null ? e : e.copyWith(value: redactCredentials(
                  e.value!,
                )),
          )
          .toList();
      final breadcrumbs = event.breadcrumbs
          ?.map(
            (b) => b.message == null
                ? b
                : b.copyWith(message: redactCredentials(b.message!)),
          )
          .toList();
      return event.copyWith(
        message: event.message == null
            ? null
            : SentryMessage(redactCredentials(event.message!.formatted)),
        exceptions: exceptions,
        breadcrumbs: breadcrumbs,
      );
    } catch (_) {
      return null;
    }
  }
}
