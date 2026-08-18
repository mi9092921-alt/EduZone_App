import 'package:app/core/error/exceptions.dart';
import 'package:app/core/error/failures.dart';
import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/shared/utils/app_snackbar.dart';
import 'package:app/shared/utils/error_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BuildContext localizedContext;

  Widget buildLocalizedApp() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Builder(
        builder: (context) {
          localizedContext = context;
          return const Scaffold(body: SizedBox());
        },
      ),
    );
  }

  group('ErrorHandler.getMessage', () {
    testWidgets('maps InvalidCredentialsException to the auth error message', (tester) async {
      await tester.pumpWidget(buildLocalizedApp());
      final l10n = AppLocalizations.of(localizedContext)!;

      final message = ErrorHandler.getMessage(localizedContext, const InvalidCredentialsException());

      expect(message, l10n.errorAuth);
    });

    testWidgets('maps NoInternetException to the network error message', (tester) async {
      await tester.pumpWidget(buildLocalizedApp());
      final l10n = AppLocalizations.of(localizedContext)!;

      final message = ErrorHandler.getMessage(localizedContext, const NoInternetException());

      expect(message, l10n.errorNetwork);
    });

    testWidgets('maps RequestTimeoutException to the network error message', (tester) async {
      await tester.pumpWidget(buildLocalizedApp());
      final l10n = AppLocalizations.of(localizedContext)!;

      final message = ErrorHandler.getMessage(localizedContext, const RequestTimeoutException());

      expect(message, l10n.errorNetwork);
    });

    testWidgets('unwraps a Failure thrown directly (e.g. from notifications_provider) '
        'and classifies it the same as the exception it was derived from', (tester) async {
      await tester.pumpWidget(buildLocalizedApp());
      final l10n = AppLocalizations.of(localizedContext)!;

      final message = ErrorHandler.getMessage(localizedContext, const NetworkFailure());

      expect(message, l10n.errorNetwork);
    });

    testWidgets('maps MaxDevicesReachedException to the max-devices message', (tester) async {
      await tester.pumpWidget(buildLocalizedApp());
      final l10n = AppLocalizations.of(localizedContext)!;

      final message = ErrorHandler.getMessage(localizedContext, const MaxDevicesReachedException());

      expect(message, l10n.errorMaxDevices);
    });

    testWidgets('maps DeviceAlreadyBoundException to the device-bound message', (tester) async {
      await tester.pumpWidget(buildLocalizedApp());
      final l10n = AppLocalizations.of(localizedContext)!;

      final message = ErrorHandler.getMessage(localizedContext, const DeviceAlreadyBoundException());

      expect(message, l10n.errorDeviceBound);
    });

    testWidgets('maps RateLimitedException to the rate-limit message, rounding seconds up to minutes', (tester) async {
      await tester.pumpWidget(buildLocalizedApp());
      final l10n = AppLocalizations.of(localizedContext)!;

      // 90 seconds -> ceil(90/60) = 2 minutes.
      final message = ErrorHandler.getMessage(
        localizedContext,
        const RateLimitedException(retryAfterSeconds: 90),
      );

      expect(message, l10n.errorRateLimit(2));
    });

    testWidgets('maps UnauthenticatedException to the auth error message (fallback)', (tester) async {
      await tester.pumpWidget(buildLocalizedApp());
      final l10n = AppLocalizations.of(localizedContext)!;

      final message = ErrorHandler.getMessage(localizedContext, const UnauthenticatedException());

      expect(message, l10n.errorAuth);
    });

    testWidgets('maps EmailNotConfirmedException to the email-not-confirmed message', (tester) async {
      await tester.pumpWidget(buildLocalizedApp());
      final l10n = AppLocalizations.of(localizedContext)!;

      final message = ErrorHandler.getMessage(localizedContext, const EmailNotConfirmedException());

      expect(message, l10n.errorEmailNotConfirmed);
    });

    testWidgets('maps ServerException to the localized generic error message', (tester) async {
      await tester.pumpWidget(buildLocalizedApp());
      final l10n = AppLocalizations.of(localizedContext)!;

      final message = ErrorHandler.getMessage(
        localizedContext,
        const ServerException('Custom backend failure'),
      );

      expect(message, l10n.errorGeneric);
    });

    testWidgets('falls back to the generic error message for unknown errors', (tester) async {
      await tester.pumpWidget(buildLocalizedApp());
      final l10n = AppLocalizations.of(localizedContext)!;

      final message = ErrorHandler.getMessage(localizedContext, Exception('boom'));

      expect(message, l10n.errorGeneric);
    });

    testWidgets('returns error.toString() when localization is unavailable', (tester) async {
      late BuildContext unlocalizedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              unlocalizedContext = context;
              return const SizedBox();
            },
          ),
        ),
      );

      const error = NoInternetException();
      final message = ErrorHandler.getMessage(unlocalizedContext, error);

      expect(message, error.toString());
    });
  });

  group('ErrorHandler.handle', () {
    testWidgets('shows a Snackbar with the localized error message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: FeedbackService.messengerKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              localizedContext = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );
      final l10n = AppLocalizations.of(localizedContext)!;

      ErrorHandler.handle(localizedContext, const NoInternetException());
      await tester.pump();

      expect(find.text(l10n.errorNetwork), findsOneWidget);
    });
  });
}
