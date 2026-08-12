import 'package:flutter/material.dart';

import '../../../core/l10n/arb/app_localizations.dart';
import '../../../shared/widgets/app_refresh_indicator.dart';
import '../../tokens/app_colors.dart';
import '../status/app_empty_state.dart';

/// A universal, flexible wrapper for all screens in the application.
/// Enforces the baseline background color and handles common layout structures.
class AppScreen extends StatelessWidget {
  const AppScreen({
    super.key,
    required this.child,
    this.scrollable = true,
    this.safeArea = true,
    this.isLoading = false,
    this.useScaffold = true,
    this.error,
    this.onRetry,
    this.onRefresh,
    this.refreshEdgeOffset,
    this.padding,
    this.backgroundColor,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  final Widget child;
  final bool scrollable;
  final bool safeArea;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;
  final Future<void> Function()? onRefresh;
  final double? refreshEdgeOffset;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool useScaffold;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    Widget content;
    if (error != null) {
      content = AppEmptyState(
        title: l10n?.errorGeneric ?? 'Something went wrong',
        description: error!,
        icon: Icons.error_outline,
        actionLabel: l10n?.retryButton ?? 'Retry',
        onActionPressed: onRetry,
      );
    } else {
      content = child;
    }

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    if (safeArea) {
      content = SafeArea(child: content);
    }

    if (scrollable) {
      content = SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: content,
      );
    }

    if (onRefresh != null) {
      content = AppRefreshIndicator(
        onRefresh: onRefresh!,
        edgeOffset: refreshEdgeOffset ??
            ((appBar == null && safeArea)
                ? MediaQuery.paddingOf(context).top
                : 0),
        child: content,
      );
    }

    if (isLoading) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          content,
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black26,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          ),
        ],
      );
    }

    if (!useScaffold) {
      return ColoredBox(
        color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor:
          backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      body: content,
    );
  }
}
