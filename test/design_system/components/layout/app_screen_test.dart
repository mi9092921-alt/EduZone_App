import 'package:app/design_system/components/layout/app_screen.dart';
import 'package:app/design_system/components/status/app_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppScreen displays content and supports optional elements', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppScreen(
          appBar: AppBar(title: const Text('Title')),
          bottomNavigationBar: const BottomAppBar(child: Text('Bottom')),
          child: const Text('Screen Content'),
        ),
      ),
    );

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Bottom'), findsOneWidget);
    expect(find.text('Screen Content'), findsOneWidget);
  });

  testWidgets('AppScreen displays loading overlay when isLoading is true', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppScreen(isLoading: true, child: Text('Under Loading')),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Under Loading'), findsOneWidget);
  });

  testWidgets(
    'AppScreen shows an AppEmptyState with the error message instead of '
    'child when `error` is set, using the built-in English fallback copy '
    '(no AppLocalizations wired up in this MaterialApp)',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppScreen(
            error: 'Could not load your courses',
            child: Text('Should be hidden while erroring'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text('Could not load your courses'), findsOneWidget);
      expect(find.text('Should be hidden while erroring'), findsNothing);
    },
  );

  testWidgets('AppScreen invokes onRetry when the error state\'s retry '
      'button is tapped', (WidgetTester tester) async {
    bool retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AppScreen(
          error: 'Network error',
          onRetry: () => retried = true,
          child: const Text('Content'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('AppScreen wraps content in a RefreshIndicator when '
      'onRefresh is provided', (WidgetTester tester) async {
    var refreshed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AppScreen(
          onRefresh: () async => refreshed = true,
          child: SizedBox(height: 2000, child: Container()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);

    await tester.fling(find.byType(RefreshIndicator), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(refreshed, isTrue);
  });

  testWidgets('AppScreen does not wrap content in a RefreshIndicator when '
      'onRefresh is null', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppScreen(child: Text('No refresh here')),
      ),
    );

    expect(find.byType(RefreshIndicator), findsNothing);
  });

  testWidgets('AppScreen with useScaffold: false renders a ColoredBox '
      'instead of a Scaffold', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppScreen(useScaffold: false, child: Text('Bare content')),
      ),
    );

    expect(find.byType(Scaffold), findsNothing);
    // NOTE: find.byType(ColoredBox) alone is brittle — MaterialApp /
    // WidgetsApp can render their own internal ColoredBox depending on
    // the Flutter SDK version, independent of AppScreen's own root
    // widget. Scope the finder to AppScreen's subtree so this test only
    // asserts on the ColoredBox that AppScreen itself returns.
    // See IMPLEMENTATION.md / TEST-BUG-003.
    expect(
      find.descendant(
        of: find.byType(AppScreen),
        matching: find.byType(ColoredBox),
      ),
      findsOneWidget,
    );
    expect(find.text('Bare content'), findsOneWidget);
  });

  testWidgets('AppScreen applies the given padding around its child', (
    WidgetTester tester,
  ) async {
    const padding = EdgeInsets.all(24);
    await tester.pumpWidget(
      const MaterialApp(
        home: AppScreen(
          padding: padding,
          scrollable: false,
          safeArea: false,
          child: Text('Padded'),
        ),
      ),
    );

    final paddingWidget = tester.widget<Padding>(
      find.ancestor(
        of: find.text('Padded'),
        matching: find.byType(Padding),
      ).first,
    );
    expect(paddingWidget.padding, padding);
  });
}
