import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/arb/app_localizations.dart';
import '../../../design_system/design_system.dart';
import 'course_card_badges.dart';
import 'course_card_base.dart';
import 'course_card_data.dart';
import 'course_card_image.dart';

/// Card used on Discover, Search, and Saved Courses screens.
class DiscoverCourseCard extends StatelessWidget {
  final DiscoverCourseVM data;
  final bool isHorizontal;
  final VoidCallback? onTap;
  final String? footerBadgeLabel;
  final Widget? actionButton;

  /// When false, the level badge (e.g. "BEGINNER") is hidden.
  /// Pass [showLevelBadge]: false from screens where the badge is not needed
  /// (e.g. SavedCoursesScreen) without affecting Discover/Search.
  final bool showLevelBadge;

  const DiscoverCourseCard({
    super.key,
    required this.data,
    this.isHorizontal = false,
    this.onTap,
    this.footerBadgeLabel,
    this.actionButton,
    this.showLevelBadge = true,
  });

  void _defaultNavigation(BuildContext context) {
    context.push('/discover/course-preview/${data.id}');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    final imageWidget = Stack(
      fit: StackFit.expand,
      children: [
        courseCardImage(data.thumbnailUrl, colors),
        if (showLevelBadge && data.level != null && data.level!.isNotEmpty)
          PositionedDirectional(
            top: AppSpacing.sm,
            end: AppSpacing.sm,
            child: _buildLevelBadge(context, data.level!, l10n),
          ),
        if (data.isNew)
          const PositionedDirectional(
            top: AppSpacing.sm,
            start: AppSpacing.sm,
            child: _NewBadge(),
          ),
      ],
    );

    // Content is built so the price badge is always pinned to the bottom of
    // the card, regardless of title length, instructor presence, or rating
    // presence. The Spacer only works because CourseCardBase wraps this in
    // an Expanded (see `expandContent: true` below), which gives the Column
    // a bounded height to push against.
    final contentWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.title,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
            height: 1.15,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs2),
        if (data.instructorName != null && data.instructorName!.isNotEmpty) ...[
          Text(
            data.instructorName!,
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs2),
        ],
        _buildDiscoverMetaRow(colors, l10n),
        // ignore: todo
        // TODO(rating): fixed placeholder rating until the ratings table
        // exists — always shown regardless of data.rating.
        const SizedBox(height: AppSpacing.xs2),
        _buildRating(colors),
        const Spacer(),
        Row(
          children: [
            ?actionButton,
            if (actionButton != null) const SizedBox(width: AppSpacing.sm),
            const Spacer(),
            _buildPriceBadge(colors, l10n),
          ],
        ),
      ],
    );

    return CourseCardBase(
      image: imageWidget,
      content: contentWidget,
      isHorizontal: isHorizontal,
      semanticLabel: data.title,
      onTap: onTap ?? () => _defaultNavigation(context),
      // Slightly taller aspect ratio (was 16:9) trims a bit of image height
      // without cropping more of the thumbnail's usable area.
      verticalImageAspectRatio: 2.0,
      // Gives the content column a bounded height in the vertical layout so
      // the Spacer above the price badge can push it to the bottom.
      expandContent: true,
      // Fix: the horizontal layout carries richer content than other cards
      // (title + instructor + meta row + rating + price/footer badge), so
      // CourseCardBase's generic defaults (height 100 / image width 95) are
      // not enough and were causing a RenderFlex overflow / squeezed layout
      // (seen in SavedCoursesScreen and Discover search results). Give this
      // card its own horizontal sizing instead of relying on the defaults.
      horizontalHeight: isHorizontal ? 136 : 100,
      // Square thumbnail in the horizontal layout (width == height) for
      // Saved Courses, Discover/Search results.
      horizontalImageWidth: isHorizontal ? 136 : 95,
      contentPadding: isHorizontal
          ? const EdgeInsetsDirectional.fromSTEB(
              0,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            )
          : const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.sm,
              0,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
    );
  }

  Widget _buildLevelBadge(
    BuildContext context,
    String level,
    AppLocalizations l10n,
  ) {
    final colors = AppColors.of(context);
    String localized = level;
    final l = level.toUpperCase();
    if (l == 'BEGINNER') localized = l10n.levelBeginner;
    if (l == 'INTERMEDIATE') localized = l10n.levelIntermediate;
    if (l == 'ADVANCED') localized = l10n.levelAdvanced;

    return CourseCardOverlayBadge(
      child: Text(
        localized.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildDiscoverMetaRow(
    DesignSystemColors colors,
    AppLocalizations l10n,
  ) {
    final chips = <Widget>[
      if (data.totalLessons != null && data.totalLessons! > 0)
        _buildMetaChip(
          Icons.menu_book_rounded,
          _formatLessons(data.totalLessons!, l10n),
          colors,
        ),
      if (data.durationMinutes != null && data.durationMinutes! > 0)
        _buildMetaChip(
          Icons.schedule_rounded,
          _formatDuration(data.durationMinutes!),
          colors,
        ),
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs2,
      children: chips,
    );
  }

  Widget _buildMetaChip(
    IconData icon,
    String label,
    DesignSystemColors colors,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: colors.textMuted),
        const SizedBox(width: 3),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: colors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _formatLessons(int count, AppLocalizations l10n) {
    return l10n.lessonsCount(count);
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String _formatPrice(double price) {
    final formatted = price % 1 == 0
        ? price.toInt().toString()
        : price.toStringAsFixed(2);
    return '\$$formatted';
  }

  // ignore: todo
  // TODO(rating): remove this placeholder and switch back to data.rating /
  // data.ratingCount once the ratings table exists.
  static const double _placeholderRating = 4.8;

  Widget _buildRating(DesignSystemColors colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: AppColors.warning, size: 18),
        const SizedBox(width: AppSpacing.xs2),
        Text(
          _placeholderRating.toStringAsFixed(1),
          style: AppTextStyles.labelSmall.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceBadge(DesignSystemColors colors, AppLocalizations l10n) {
    final label =
        footerBadgeLabel ??
        (data.isFree
            ? l10n.freeLabel
            : data.price != null && data.price! > 0
            ? _formatPrice(data.price!)
            : l10n.freeLabel);
    final badgeColor = data.isFree ? colors.success : colors.primary;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: badgeColor.withValues(alpha: 0.24)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs2,
          ),
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: badgeColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pulsing "new" badge shown on the thumbnail of newly published courses.
///
/// Kept private to this file: it is only ever used by [DiscoverCourseCard],
/// unlike [CourseCardOverlayBadge] which it wraps and which is shared with
/// the level badge above.
class _NewBadge extends StatefulWidget {
  const _NewBadge();

  @override
  State<_NewBadge> createState() => _NewBadgeState();
}

class _NewBadgeState extends State<_NewBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // check-ignore -- continuous subtle badge pulse period
    )..repeat(reverse: true);
    // Subtler pulse range (was 2.0–8.0) — reads as a soft elevation lift
    // rather than a glow.
    _glowAnimation = Tween<double>(
      begin: 1.0,
      end: 4.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow( // check-ignore -- animated dynamic glow driven by Tween value
                // Lower opacity (was 0.4) keeps the badge noticeable without
                // overpowering the rest of the card.
                color: colors.primary.withValues(alpha: 0.22),
                blurRadius: _glowAnimation.value,
                spreadRadius: _glowAnimation.value / 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: child!,
        );
      },
      child: CourseCardOverlayBadge(
        tint: colors.primary,
        child: Text(
          l10n.newStatusLabel,
          style: AppTextStyles.labelSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}
