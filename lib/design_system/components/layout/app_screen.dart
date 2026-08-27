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
      // `error` here is already the caller-classified, user-facing message
      // (e.g. via `ErrorHandler.getMessage()` -- "No internet connection."
      // vs a real server error) -- every screen that sets it did the work
      // of telling offline apart from a genuine failure. Showing a fixed
      // `errorGeneric` ("An error occurred") as the large bold title and
      // relegating the actual, already-correct reason to small print
      // underneath defeated that classification from the user's point of
      // view: every failure *looked* like the same generic error at a
      // glance, connectivity included. The classified message belongs in
      // the headline.
      content = AppEmptyState(
        title: error!,
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

    // RefreshIndicator only responds to a swipe if it can see scroll
    // notifications bubbling up from a real Scrollable. `AppEmptyState`
    // (the error widget above) is a plain Center/Column with nothing
    // scrollable inside it. Callers that pass `scrollable: false` because
    // their *normal* `child` already supplies its own scroll view (e.g.
    // `AppPageScaffold`'s `CustomScrollView`) unintentionally lost pull-to-
    // refresh the moment an error occurred, since the CustomScrollView is
    // discarded above and replaced by the non-scrollable error widget.
    // Give the error state its own scrollable whenever a refresh callback
    // is wired up, regardless of `scrollable`, so pull-to-refresh keeps
    // working and users aren't limited to the Retry button.
    final bool errorNeedsOwnScrollable =
        error != null && !scrollable && onRefresh != null;

    if (scrollable || errorNeedsOwnScrollable) {
      // UI-001: `SingleChildScrollView` sizes its child to its natural
      // (unbounded) height, so a `Center`-based full-page body — every
      // `AppEmptyState` error/empty state rendered through this widget,
      // plus screens like `LockedScreen` that build their own `Center` —
      // was never actually centered: it just collapsed to whatever height
      // its content needed and sat at the top of the scroll view, leaving
      // the rest of the screen as dead space below it. Wrapping the
      // scrollable's child in a `ConstrainedBox` with `minHeight` pinned
      // to the available viewport height fixes this: short content is
      // now genuinely centered in the visible area (matching what a user
      // expects from a system-style alert/empty state), while content
      // taller than the viewport is completely unaffected and still
      // scrolls exactly as before — `minHeight` never caps how tall the
      // child can grow.
      final Widget contentToScroll = content;
      content = LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: contentToScroll,
            ),
          );
        },
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
