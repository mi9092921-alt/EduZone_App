import 'package:app/design_system/components/layout/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the title and sliver content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppPageScaffold(
          title: 'Courses',
          slivers: [
            SliverToBoxAdapter(child: Text('Sliver body')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Courses'), findsOneWidget);
    expect(find.text('Sliver body'), findsOneWidget);
  });

  testWidgets('renders every provided sliver in order', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppPageScaffold(
          title: 'Title',
          slivers: [
            SliverToBoxAdapter(child: Text('First')),
            SliverToBoxAdapter(child: Text('Second')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('shows AppEmptyState with the error message instead of '
      'slivers when `error` is set', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppPageScaffold(
          title: 'Title',
          error: 'Network unavailable',
          onRetry: () {},
          slivers: [const SliverToBoxAdapter(child: Text('Should be hidden'))],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Network unavailable'), findsOneWidget);
    expect(find.text('Should be hidden'), findsNothing);
  });

  testWidgets('tapping retry after an error invokes onRetry', (tester) async {
    bool retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AppPageScaffold(
          title: 'Title',
          error: 'Failed to load',
          onRetry: () => retried = true,
          slivers: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(retried, isTrue);
  });

  testWidgets('pull-to-refresh triggers onRefresh', (tester) async {
    var refreshed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AppPageScaffold(
          title: 'Title',
          onRefresh: () async => refreshed = true,
          slivers: [
            SliverFillRemaining(child: Container(height: 2000)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Standard RefreshIndicator test pattern: a downward fling on the
    // scroll view, then explicit timed pumps so the indicator's own
    // show/hide animation has time to complete (pumpAndSettle alone can
    // time out waiting on it).
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 300),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(refreshed, isTrue);
  });
}
