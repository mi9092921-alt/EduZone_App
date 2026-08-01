import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// A reusable RefreshIndicator that follows the app's design system.
/// It automatically accounts for the top [SafeArea] (status bar) by default.
class AppRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? color;
  final Color? backgroundColor;

  final double edgeOffset;

  const AppRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.color,
    this.backgroundColor,
    this.edgeOffset = 0,
  });

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: color ?? AppColors.primary,
      backgroundColor: backgroundColor ?? ds.surface,
      edgeOffset: edgeOffset,
      child: child,
    );
  }
}
