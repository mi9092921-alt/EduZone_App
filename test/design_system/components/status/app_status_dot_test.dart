import 'package:app/design_system/components/status/app_status_dot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('defaults to a 12x12 circle in the given color', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: AppStatusDot(color: Colors.green))),
      ),
    );
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byType(AppStatusDot));
    expect(size, const Size(12, 12));

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(AppStatusDot),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, Colors.green);
    expect(decoration.shape, BoxShape.circle);
  });

  testWidgets('honors a custom size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: AppStatusDot(color: Colors.red, size: 20)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byType(AppStatusDot));
    expect(size, const Size(20, 20));
  });

  testWidgets('adds a glow BoxShadow only when hasPulse is true',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: AppStatusDot(color: Colors.orange)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    var container = tester.widget<Container>(
      find.descendant(
        of: find.byType(AppStatusDot),
        matching: find.byType(Container),
      ),
    );
    var decoration = container.decoration! as BoxDecoration;
    expect(decoration.boxShadow, isNull);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppStatusDot(color: Colors.orange, hasPulse: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    container = tester.widget<Container>(
      find.descendant(
        of: find.byType(AppStatusDot),
        matching: find.byType(Container),
      ),
    );
    decoration = container.decoration! as BoxDecoration;
    expect(decoration.boxShadow, isNotNull);
    expect(decoration.boxShadow, hasLength(1));
  });
}
