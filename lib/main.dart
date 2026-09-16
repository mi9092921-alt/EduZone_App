import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_initializer.dart';
import 'app/main_app.dart';
import 'core/feature_flags/feature_flags_provider.dart';
import 'core/services/sentry_service.dart';
import 'core/utils/global_error_handler.dart';

Future<void> main() async {
  // SentryFlutter.init creates its own runZonedGuarded, which
  // captures all uncaught async errors automatically.
  // If SENTRY_DSN is empty, the appRunner runs without Sentry.
  await SentryService.initialize(
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize Global Error Handler (Flutter framework + platform errors)
      GlobalErrorHandler.init();

      // Custom Error Widget for Production
      ErrorWidget.builder =
          (details) => AppProductionErrorScreen(details: details);

      // Bootstrap Core Services
      await AppInitializer.init();

      runApp(
        ProviderScope(
          // Composition-root wiring for the feature-flag cache: core/ cannot
          // import lib/app/ to reach AppInitializer.prefs directly (see the
          // provider's doc comment), so the bootstrapped instance is handed
          // in here — safe because AppInitializer.init() has already run.
          overrides: [
            featureFlagPrefsProvider.overrideWithValue(AppInitializer.prefs),
          ],
          child: const EduZoneApp(),
        ),
      );
    },
  );
}
