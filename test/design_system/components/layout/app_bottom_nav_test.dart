import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/design_system/components/layout/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestableWidget({required int currentIndex, ValueChanged<int>? onTap}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        bottomNavigationBar: AppBottomNav(
          currentIndex: currentIndex,
          onTap: onTap ?? (_) {},
        ),
      ),
    );
  }

  testWidgets('renders all five destination labels', (tester) async {
    await tester.pumpWidget(buildTestableWidget(currentIndex: 0));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Courses'), findsOneWidget);
    expect(find.text('To-Do'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('reflects currentIndex as the selected NavigationBar index',
      (tester) async {
    await tester.pumpWidget(buildTestableWidget(currentIndex: 2));
    await tester.pumpAndSettle();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 2);
  });

  testWidgets('tapping a destination invokes onTap with its index',
      (tester) async {
    int? tappedIndex;
    await tester.pumpWidget(
      buildTestableWidget(currentIndex: 0, onTap: (i) => tappedIndex = i),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Courses'));
    await tester.pumpAndSettle();

    expect(tappedIndex, 2);
  });

  testWidgets('buildNavDestinationSpecs returns 5 specs in a stable order',
      (tester) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final specs =
        buildNavDestinationSpecs(AppLocalizations.of(capturedContext)!);

    expect(specs, hasLength(5));
    expect(specs.map((s) => s.label), [
      'Home',
      'Discover',
      'Courses',
      'To-Do',
      'Profile',
    ]);
    // Each destination must define a distinct selected/unselected icon pair
    // so the active tab is visually distinguishable.
    for (final spec in specs) {
      expect(spec.icon, isNot(spec.selectedIcon));
    }
  });
}
