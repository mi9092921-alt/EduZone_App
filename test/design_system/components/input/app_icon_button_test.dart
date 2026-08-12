import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppIconButton renders icon and triggers callback on tap', (
    WidgetTester tester,
  ) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppIconButton(
            icon: Icons.visibility,
            semanticLabel: 'Show password',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.visibility), findsOneWidget);
    await tester.tap(find.byType(AppIconButton));
    expect(tapped, isTrue);
  });

  testWidgets('AppIconButton applies semantics label and toggled state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppIconButton(
            icon: Icons.visibility_off,
            semanticLabel: 'Show password',
            toggledState: true,
            onPressed: () {},
          ),
        ),
      ),
    );

    final semanticsWidget = tester.widget<Semantics>(
      find.descendant(
        of: find.byType(AppIconButton),
        matching: find.byType(Semantics),
      ).first,
    );
    expect(semanticsWidget.properties.label, 'Show password');
    expect(semanticsWidget.properties.toggled, isTrue);
  });
}
