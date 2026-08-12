import 'package:app/design_system/components/progress/app_progress_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a CircularProgressIndicator while isLoading is true',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppProgressRing(progress: 0.5, isLoading: true),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('shows the rounded percentage label by default once settled',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppProgressRing(progress: 0.75)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('75%'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('hides the label when showLabel is false', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppProgressRing(progress: 0.5, showLabel: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('renders at the requested size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppProgressRing(progress: 0.5, size: 96)),
      ),
    );
    await tester.pumpAndSettle();

    final sizedBoxOfRequestedSize = find.descendant(
      of: find.byType(AppProgressRing),
      matching: find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 96 && widget.height == 96,
      ),
    );
    expect(sizedBoxOfRequestedSize, findsWidgets);
  });

  testWidgets('does not throw for a completed (1.0) or empty (0.0) progress',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppProgressRing(progress: 1.0)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('100%'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppProgressRing(progress: 0.0)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('0%'), findsOneWidget);
  });
}
