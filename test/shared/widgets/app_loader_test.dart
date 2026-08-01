import 'package:app/shared/widgets/app_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppLoader displays indicator', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppLoader()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AppFullScreenLoader displays indicator with background', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AppFullScreenLoader()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('full_screen_loader_bg')), findsOneWidget);
  });
}
