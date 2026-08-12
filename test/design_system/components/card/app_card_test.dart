import 'package:app/design_system/components/card/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppCard displays child content', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppCard(child: Text('Card Content'))),
      ),
    );

    expect(find.text('Card Content'), findsOneWidget);
  });

  testWidgets('AppCard handles tap events', (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppCard(
            onTap: () => tapped = true,
            child: const Text('Tap Me'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tap Me'));
    expect(tapped, true);
  });
}
