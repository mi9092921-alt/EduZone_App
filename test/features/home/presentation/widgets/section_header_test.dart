import 'package:app/features/home/presentation/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('SectionHeader', () {
    testWidgets('renders the given title', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const SectionHeader(title: 'Recent Courses')),
      );

      expect(find.text('Recent Courses'), findsOneWidget);
    });

    testWidgets('does not render a trailing widget when none is provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const SectionHeader(title: 'My Todos')),
      );

      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('renders the trailing widget when provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const SectionHeader(
            title: 'My Todos',
            trailing: Text('See all'),
          ),
        ),
      );

      expect(find.text('See all'), findsOneWidget);
      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('invokes onTrailingTapped when the trailing widget is tapped',
        (WidgetTester tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        buildTestableWidget(
          SectionHeader(
            title: 'My Todos',
            trailing: const Text('See all'),
            onTrailingTapped: () => tapCount++,
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(tapCount, 1);
    });

    testWidgets('does not throw when trailing is provided without a callback',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const SectionHeader(title: 'My Todos', trailing: Text('See all')),
        ),
      );

      // onTrailingTapped is null; tapping should be a no-op, not a crash.
      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(find.text('See all'), findsOneWidget);
    });
  });
}
