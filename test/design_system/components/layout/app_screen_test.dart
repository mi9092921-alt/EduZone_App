import 'package:app/design_system/components/layout/app_screen.dart';
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
}
