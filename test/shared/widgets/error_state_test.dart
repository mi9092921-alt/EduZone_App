import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/shared/widgets/error_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ErrorState displays error message and triggers retry', (
    WidgetTester tester,
  ) async {
    bool retried = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ar'),
        home: Scaffold(
          body: ErrorState(
            message: 'Network Failure',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('حدث خطأ'), findsOneWidget); // Default title in Arabic
    expect(find.text('Network Failure'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget); // Default button label

    await tester.tap(find.text('إعادة المحاولة'));
    expect(retried, true);
  });
}
