import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppEmptyState displays title, optional icon, and action', (
    WidgetTester tester,
  ) async {
    bool actionPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            title: 'Nothing here',
            icon: Icons.history,
            actionLabel: 'Retry',
            onActionPressed: () => actionPressed = true,
          ),
        ),
      ),
    );

    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.byIcon(Icons.history), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(actionPressed, isTrue);
  });
}
