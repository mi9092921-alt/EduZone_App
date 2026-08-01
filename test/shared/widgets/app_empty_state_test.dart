import 'package:app/shared/widgets/app_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppEmptyState displays message and optional icon/action', (
    WidgetTester tester,
  ) async {
    bool actionPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            message: 'Nothing here',
            icon: Icons.history,
            action: ElevatedButton(
              onPressed: () => actionPressed = true,
              child: const Text('Retry'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.byIcon(Icons.history), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    expect(actionPressed, true);
  });
}
