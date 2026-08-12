import 'package:flutter/material.dart';

/// A [SliverPersistentHeaderDelegate] that pins a [TabBar] to the top of a
/// [CustomScrollView], with a solid background so content doesn't show
/// through while scrolling underneath it.
///
/// This used to be copy-pasted as a private `_SliverAppBarDelegate` class in
/// both `course_details_screen.dart` and `course_preview_screen.dart` (the
/// only difference being an optional divider). It's now a single shared
/// widget so both — and any future tabbed screen — stay in sync.
class CollapsingTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  /// Whether to draw a hairline divider under the tab bar. Defaults to
  /// `false`; pass `true` for screens (like course details) that want a
  /// visual separation from the content below.
  final Color? dividerColor;

  const CollapsingTabBarDelegate({
    required this.tabBar,
    required this.backgroundColor,
    this.dividerColor,
  });

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    if (dividerColor == null) {
      return ColoredBox(color: backgroundColor, child: tabBar);
    }
    return ColoredBox(
      color: backgroundColor,
      child: Column(
        children: [
          tabBar,
          Divider(height: 1, color: dividerColor),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant CollapsingTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor ||
        dividerColor != oldDelegate.dividerColor;
  }
}
