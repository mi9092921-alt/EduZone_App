import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/design_system/components/status/app_connectivity_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  testWidgets('renders the title and message', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        AppConnectivityError(
          title: 'No Connection',
          message: 'Check your internet and try again.',
          onRetry: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No Connection'), findsOneWidget);
    expect(find.text('Check your internet and try again.'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
  });

  testWidgets('tapping the retry button invokes onRetry', (tester) async {
    bool retried = false;
    await tester.pumpWidget(
      buildTestableWidget(
        AppConnectivityError(
          title: 'No Connection',
          message: 'Offline',
          onRetry: () => retried = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('shows a loading indicator on the retry button when '
      'isLoading is true', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        AppConnectivityError(
          title: 'No Connection',
          message: 'Offline',
          onRetry: () {},
          isLoading: true,
        ),
      ),
    );
    // NOTE: intentionally pump() and NOT pumpAndSettle() here.
    // AppButton renders an indeterminate CircularProgressIndicator
    // (no `value:`) when isLoading is true, which drives a repeating
    // AnimationController that never settles — pumpAndSettle() would
    // time out and fail this test regardless of AppConnectivityError's
    // own correctness. See IMPLEMENTATION.md / TEST-BUG-002.
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('scales content down when isFullPage is false', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        AppConnectivityError(
          title: 'No Connection',
          message: 'Offline',
          onRetry: () {},
          isFullPage: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // isFullPage: false uses a 0.7x size multiplier -- the retry button
    // becomes a fixed 160px box instead of stretching full width.
    final sizedBox = find.ancestor(
      of: find.text('Retry'),
      matching: find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 160,
      ),
    );
    expect(sizedBox, findsOneWidget);
  });
}
