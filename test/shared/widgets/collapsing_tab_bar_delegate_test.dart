import 'package:app/shared/widgets/collapsing_tab_bar_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TabBar buildTabBar() {
    return const TabBar(
      tabs: [Tab(text: 'About'), Tab(text: 'Curriculum')],
    );
  }

  test('minExtent and maxExtent both equal the TabBar preferred height', () {
    final tabBar = buildTabBar();
    final delegate = CollapsingTabBarDelegate(
      tabBar: tabBar,
      backgroundColor: Colors.white,
    );

    expect(delegate.minExtent, tabBar.preferredSize.height);
    expect(delegate.maxExtent, tabBar.preferredSize.height);
  });

  testWidgets('renders without a divider when dividerColor is not set', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            body: Builder(
              builder: (context) => CollapsingTabBarDelegate(
                tabBar: buildTabBar(),
                backgroundColor: Colors.white,
              ).build(context, 0, false),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('renders a divider when dividerColor is set (course details style)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            body: Builder(
              builder: (context) => CollapsingTabBarDelegate(
                tabBar: buildTabBar(),
                backgroundColor: Colors.white,
                dividerColor: Colors.grey,
              ).build(context, 0, false),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
  });

  test('shouldRebuild is true when the background color changes', () {
    final tabBar = buildTabBar();
    final oldDelegate = CollapsingTabBarDelegate(
      tabBar: tabBar,
      backgroundColor: Colors.white,
    );
    final newDelegate = CollapsingTabBarDelegate(
      tabBar: tabBar,
      backgroundColor: Colors.black,
    );

    expect(newDelegate.shouldRebuild(oldDelegate), isTrue);
  });

  test('shouldRebuild is false when nothing changed', () {
    final tabBar = buildTabBar();
    final oldDelegate = CollapsingTabBarDelegate(
      tabBar: tabBar,
      backgroundColor: Colors.white,
    );
    final newDelegate = CollapsingTabBarDelegate(
      tabBar: tabBar,
      backgroundColor: Colors.white,
    );

    expect(newDelegate.shouldRebuild(oldDelegate), isFalse);
  });
}
