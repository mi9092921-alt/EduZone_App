import 'package:app/design_system/components/status/app_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the title only when nothing else is provided',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppEmptyState(title: 'No courses yet')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No courses yet'), findsOneWidget);
  });

  testWidgets('renders the icon only when one is provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppEmptyState(title: 'Empty', icon: Icons.inbox_rounded),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.inbox_rounded), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppEmptyState(title: 'Empty')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('renders the optional description', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            title: 'No results',
            description: 'Try a different search term.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Try a different search term.'), findsOneWidget);
  });

  testWidgets('does not render an action button unless both actionLabel '
      'and onActionPressed are provided', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppEmptyState(title: 'Empty', actionLabel: 'Retry'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // actionLabel alone (no onActionPressed) must not render a button.
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('tapping the action button invokes onActionPressed',
      (tester) async {
    bool pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            title: 'Empty',
            actionLabel: 'Add a course',
            onActionPressed: () => pressed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add a course'), findsOneWidget);
    await tester.tap(find.text('Add a course'));
    expect(pressed, isTrue);
  });

  testWidgets('uses a smaller layout when isFullPage is false',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            title: 'Compact',
            icon: Icons.info_outline,
            isFullPage: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final icon = tester.widget<Icon>(find.byIcon(Icons.info_outline));
    // isFullPage: false uses a 48px icon size instead of 64px.
    expect(icon.size, 48);
  });
}
