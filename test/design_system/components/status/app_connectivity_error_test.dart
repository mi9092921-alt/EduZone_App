import 'package:app/design_system/components/status/app_connectivity_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the title and message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppConnectivityError(
            title: 'No Connection',
            message: 'Check your internet and try again.',
            onRetry: () {},
          ),
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
      MaterialApp(
        home: Scaffold(
          body: AppConnectivityError(
            title: 'No Connection',
            message: 'Offline',
            onRetry: () => retried = true,
          ),
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
      MaterialApp(
        home: Scaffold(
          body: AppConnectivityError(
            title: 'No Connection',
            message: 'Offline',
            onRetry: () {},
            isLoading: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('scales content down when isFullPage is false', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppConnectivityError(
            title: 'No Connection',
            message: 'Offline',
            onRetry: () {},
            isFullPage: false,
          ),
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
