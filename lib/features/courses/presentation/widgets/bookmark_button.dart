import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../design_system/design_system.dart';
import '../providers/courses_provider.dart';

class BookmarkButton extends ConsumerStatefulWidget {
  final String courseId;
  final double size;
  final double iconSize;
  final double backgroundOpacity;
  final double elevation;

  const BookmarkButton({
    super.key,
    required this.courseId,
    this.size = AppSizes.buttonHeight,
    this.iconSize = AppSizes.iconSm + 2,
    this.backgroundOpacity = 0.72,
    this.elevation = 1,
  });

  @override
  ConsumerState<BookmarkButton> createState() => BookmarkButtonState();
}

class BookmarkButtonState extends ConsumerState<BookmarkButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isToggling = false;

  Future<void> _onToggle() async {
    if (_isToggling) return;
    _isToggling = true;
    try {
      await ref
          .read(bookmarkedCoursesProvider.notifier)
          .toggleBookmark(widget.courseId);
      if (mounted) await _controller.forward(from: 0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.bookmarkFailed)),
        );
      }
    } finally {
      _isToggling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBookmarked = ref.watch(
      bookmarkedCoursesProvider.select(
        (state) => state.asData?.value.contains(widget.courseId) ?? false,
      ),
    );
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Semantics(
      label: isBookmarked ? l10n.bookmarkRemove : l10n.bookmarkAdd,
      button: true,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: AppSpacing.xs,
                sigmaY: AppSpacing.xs,
              ),
              child: Material(
                // Theme-aware glass surface so course artwork remains visible
                // under the overlay in compact thumbnails.
                color: colors.surface.withValues(
                  alpha: widget.backgroundOpacity,
                ),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                elevation: widget.elevation,
                child: InkWell(
                  onTap: _onToggle,
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: Icon(
                      isBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: widget.iconSize,
                      color: isBookmarked
                          ? AppColors.primary
                          : colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
