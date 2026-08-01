import 'package:app/design_system/components/button/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppButton displays label and triggers callback', (
    WidgetTester tester,
  ) async {
    bool pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            label: 'Test Button',
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    // Verify label
    expect(find.text('Test Button'), findsOneWidget);

    // Tap and verify callback
    await tester.tap(find.text('Test Button'));
    expect(pressed, true);
  });

  testWidgets('AppButton displays loading indicator when isLoading is true', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppButton(label: 'Loading...', isLoading: true)),
      ),
    );

    // Verify label is not shown as a direct Text widget (inside Row/etc) or check for indicator
    // Actually content is replaced by indicator in AppButton
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading...'), findsNothing);
  });

  testWidgets('AppButton displays leading icon', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppButton(label: 'Icon Button', leadingIcon: Icons.add),
        ),
      ),
    );

    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('Icon Button'), findsOneWidget);
  });
}
