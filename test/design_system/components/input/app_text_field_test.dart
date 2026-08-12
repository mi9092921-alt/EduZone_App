import 'package:app/design_system/components/input/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppTextField displays label and hint, and accepts input', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTextField(
            label: 'Email',
            hint: 'enter@email.com',
            controller: controller,
          ),
        ),
      ),
    );

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('enter@email.com'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'test@example.com');
    expect(controller.text, 'test@example.com');
  });

  testWidgets('AppTextField displays error text', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppTextField(label: 'Error Field', errorText: 'Required field'),
        ),
      ),
    );

    expect(find.text('Required field'), findsOneWidget);
  });

  testWidgets('AppTextField obscuring text for password', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppTextField(label: 'Password', obscureText: true),
        ),
      ),
    );

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.obscureText, true);
  });
}
