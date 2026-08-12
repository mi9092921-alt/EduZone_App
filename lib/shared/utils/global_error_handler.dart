import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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

  /// Logs errors to the console and forwards to Sentry.
  static void logError(Object error, StackTrace? stack) {
    debugPrint('--- [EduZone Error Log] ---');
    debugPrint('Error: $error');
    if (stack != null) {
      debugPrint('StackTrace: \n$stack');
    }
    debugPrint('---------------------------');

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
