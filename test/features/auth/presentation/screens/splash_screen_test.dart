import 'dart:async';

import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/auth/application/providers/auth_provider.dart';
import 'package:app/features/auth/presentation/screens/splash/animated_brand_name.dart';
import 'package:app/features/auth/presentation/screens/splash/animated_logo.dart';
import 'package:app/features/auth/presentation/screens/splash/gradient_background.dart';
import 'package:app/features/auth/presentation/screens/splash_screen.dart';
import 'package:app/shared/models/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Regression coverage for the file split of splash_screen.dart into
// screens/splash/{gradient_background, animated_logo, animated_brand_name,
// splash_brand_metrics, splash_constants}.dart — this test only asserts the
// wiring holds together after the split (each sub-widget still renders, no
// missing constants/measurements), not the pixel-level animation output.
//
// Phase 8: splash is now a ConsumerStatefulWidget — it must render the
// degraded-session surface when the auth state is AuthDegraded (previously
// a user whose session verification failed could sit on an eternally
// animating splash with no message and, once auto-retries were exhausted,
// no recovery path at all). authProvider is overridden with a fake notifier
// following the same pattern as login_screen_test.dart.
class _FakeAuth extends Auth {
  _FakeAuth(this._state);
  final AuthState _state;

  @override
  AuthState build() => _state;
}

Future<void> pumpSplash(
  WidgetTester tester, {
  Brightness? brightness,
  AuthState authState = const AuthInitializing(),
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [authProvider.overrideWith(() => _FakeAuth(authState))],
      child: MaterialApp(
        theme: brightness == Brightness.dark
            ? ThemeData.dark()
            : ThemeData.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SplashScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('renders the gradient background, logo, and brand name', (
    tester,
  ) async {
    await pumpSplash(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SplashGradientBackground), findsOneWidget);
    expect(find.byType(SplashAnimatedLogo), findsOneWidget);
    expect(find.byType(SplashAnimatedBrandName), findsOneWidget);
  });

  testWidgets('exposes semantics labels for the logo and brand name', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpSplash(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.bySemanticsLabel('EduZone logo'), findsOneWidget);
    expect(find.bySemanticsLabel('EduZone'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('renders "Edu" and "Zone" literal text', (tester) async {
    await pumpSplash(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Edu'), findsOneWidget);
    expect(find.text('Zone'), findsOneWidget);
  });

  testWidgets('does not throw across the full animation lifecycle', (
    tester,
  ) async {
    await pumpSplash(tester);
    // Advance well past the 1200ms main animation duration; the repeating
    // pulse controller keeps going on purpose (see splash_screen.dart doc
    // comment) so we pump a bounded number of frames rather than
    // pumpAndSettle (which would never settle).
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders correctly in dark mode', (tester) async {
    await pumpSplash(tester, brightness: Brightness.dark);
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.byType(SplashGradientBackground), findsOneWidget);
  });

  group('degraded-session surface (Phase 8)', () {
    testWidgets(
      'shows no degraded banner while verification is simply initializing',
      (tester) async {
        await pumpSplash(tester);
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Retrying automatically…'), findsNothing);
      },
    );

    testWidgets(
      'shows the retrying message while auto-retries are still pending',
      (tester) async {
        const degraded = AuthDegraded(error: 'errorNetwork', retryAttempt: 2);
        await pumpSplash(tester, authState: degraded);
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text("Couldn't verify your session. Retrying automatically…"),
            findsOneWidget);
        expect(find.text('Retry'), findsNothing);
      },
    );

    testWidgets(
      'shows the classified error + manual retry once auto-retries are exhausted',
      (tester) async {
        const degraded = AuthDegraded(
          error: 'errorNetwork',
          retryAttempt: Auth.maxDegradedAutoRetries,
          autoRetriesExhausted: true,
        );
        await pumpSplash(tester, authState: degraded);
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('No internet connection.'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      },
    );

    testWidgets(
      'manual retry invokes retryDegradedSession and disables double-taps',
      (tester) async {
        var retryCalls = 0;
        // The retry round-trip must still be IN FLIGHT when the second tap
        // lands — that is the only situation the button's disabled state
        // (and the screen's _isRetryingDegradedSession guard) can prevent.
        final retryInFlight = Completer<void>();
        const degraded = AuthDegraded(
          error: 'errorNetwork',
          autoRetriesExhausted: true,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(
                () => _RetryingAuth(degraded, () {
                  retryCalls++;
                  return retryInFlight.future;
                }),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SplashScreen(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.text('Retry'));
        await tester.pump();
        // While the retry is in flight the button swaps its label for a
        // spinner (no longer tappable by text) — tap the TextButton itself
        // for the second attempt; it must be disabled (onPressed == null),
        // so only one call may be recorded.
        final retryButton = tester.widget<TextButton>(
          find.byType(TextButton),
        );
        expect(retryButton.onPressed, isNull);
        expect(retryCalls, 1);

        retryInFlight.complete();
        await tester.pump();
      },
    );
  });
}

class _RetryingAuth extends Auth {
  _RetryingAuth(this._state, this._onRetry);
  final AuthState _state;
  final Future<void> Function() _onRetry;

  @override
  AuthState build() => _state;

  @override
  Future<void> retryDegradedSession() => _onRetry();
}
