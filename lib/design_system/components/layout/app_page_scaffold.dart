import 'package:flutter/material.dart';

import '../../tokens/app_spacing.dart';
import 'app_modern_header.dart';
import 'app_screen.dart';

class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.centerTitle = false,
    this.leading,
    this.actions,
    this.error,
    this.onRetry,
    this.onRefresh,
    this.controller,
    this.backgroundColor,
    this.bottomSpacing = AppSpacing.xl,
  });

  final String title;
  final List<Widget> slivers;
  final bool centerTitle;
  final Widget? leading;
  final List<Widget>? actions;
  final String? error;
  final VoidCallback? onRetry;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;
  final Color? backgroundColor;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      scrollable: false,
      safeArea: false,
      onRefresh: onRefresh,
      onRetry: onRetry,
      error: error,
      backgroundColor: backgroundColor,
      child: CustomScrollView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            snap: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: AppModernHeader(
              title: title,
              leading: leading,
              actions: actions,
              centerTitle: centerTitle,
            ),
          ),
          ...slivers,
          SliverToBoxAdapter(child: SizedBox(height: bottomSpacing)),
        ],
      ),
    );
  }
}
