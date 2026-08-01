import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/arb/app_localizations.dart';
import '../../core/cache/app_image_cache_manager.dart';
import '../../design_system/design_system.dart';

abstract class CourseCardData {
  final String id;
  final String title;
  final String thumbnailUrl;
  final String? level;
  final String? instructorName;

  const CourseCardData({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    this.level,
    this.instructorName,
  });
}

class DiscoverCourseVM extends CourseCardData {
  final int? totalLessons;
  final String? category;
  final double? rating;
  final int? ratingCount;
  final int? studentsCount;
  final int? durationMinutes;
  final double? price;
  final bool isFree;
  final bool isNew;

  const DiscoverCourseVM({
    required super.id,
    required super.title,
    required super.thumbnailUrl,
    super.level,
    super.instructorName,
    this.totalLessons,
    this.category,
    this.rating,
    this.ratingCount,
    this.studentsCount,
    this.durationMinutes,
    this.price,
    this.isFree = true,
    this.isNew = false,
  });

  /// Factory for skeleton dummy data
  factory DiscoverCourseVM.skeleton() => const DiscoverCourseVM(
    id: 'skeleton',
    title: AppSkeletonData.dummyTitle,
    thumbnailUrl: '',
    category: AppSkeletonData.dummyCategory,
    rating: 0.0,
    level: 'BEGINNER',
    instructorName: 'Instructor Name',
  );
}

class MyCourseVM extends CourseCardData {
  final int totalLessons;
  final double progress;

  const MyCourseVM({
    required super.id,
    required super.title,
    required super.thumbnailUrl,
    super.level,
    required this.totalLessons,
    required this.progress,
  });

  /// Factory for skeleton dummy data
  factory MyCourseVM.skeleton() => const MyCourseVM(
    id: 'skeleton',
    title: AppSkeletonData.dummyTitle,
    thumbnailUrl: '',
    totalLessons: 10,
    progress: 0.5,
    level: 'BEGINNER',
  );
}

class RecentCourseVM extends CourseCardData {
  final int totalLessons;
  final double progress;
  final String? currentLessonTitle;

  const RecentCourseVM({
    required super.id,
    required super.title,
    required super.thumbnailUrl,
    super.level,
    required this.totalLessons,
    required this.progress,
    this.currentLessonTitle,
  });

  /// Factory for skeleton dummy data
  factory RecentCourseVM.skeleton() => const RecentCourseVM(
    id: 'skeleton',
    title: AppSkeletonData.dummyTitle,
    thumbnailUrl: '',
    totalLessons: 10,
    progress: 0.0,
    level: 'BEGINNER',
  );
}

/// Shared layout card component providing transitions, hover effects,
/// tap handling, card borders, shadow levels, and layout structure (vertical/horizontal).
class CourseCardBase extends StatefulWidget {
  final Widget image;
  final Widget content;
  final bool isHorizontal;
  final VoidCallback? onTap;
  final double? verticalImageAspectRatio;
  final double horizontalHeight;
  final double horizontalImageWidth;
  final String semanticLabel;
  final EdgeInsetsGeometry? contentPadding;

  /// When true, the content area in vertical layout uses [Expanded] instead
  /// of [Flexible], giving bounded height so [Spacer] works correctly.
  final bool expandContent;

  const CourseCardBase({
    super.key,
    required this.image,
    required this.content,
    required this.semanticLabel,
    this.isHorizontal = false,
    this.onTap,
    this.verticalImageAspectRatio,
    this.horizontalHeight = 100,
    this.horizontalImageWidth = 95,
    this.contentPadding,
    this.expandContent = false,
  });

  @override
  State<CourseCardBase> createState() => _CourseCardBaseState();
}

class _CourseCardBaseState extends State<CourseCardBase> {
  bool _isHovered = false;
  bool _isPressed = false;

  double get _scale => _isPressed ? 0.97 : (_isHovered ? 1.02 : 1.0);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              // Lighter, more premium border weight (was 0.6).
              border: Border.all(color: colors.border.withValues(alpha: 0.35)),
              boxShadow: _isHovered || _isPressed
                  ? AppElevation.shadowMd
                  : AppElevation.shadowSm,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                onTapDown: (_) => setState(() => _isPressed = true),
                onTapUp: (_) => setState(() => _isPressed = false),
                onTapCancel: () => setState(() => _isPressed = false),
                child: widget.isHorizontal
                    ? _buildHorizontalLayout(colors)
                    : _buildVerticalLayout(colors),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalLayout(DesignSystemColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Tighter image padding frees up a little more room for content
          // (was AppSpacing.xs on all sides).
          padding: const EdgeInsets.all(AppSpacing.xs2),
          child: AspectRatio(
            aspectRatio: widget.verticalImageAspectRatio ?? 2.0,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                // Lighter image border (was 0.4).
                border: Border.all(
                  color: colors.border.withValues(alpha: 0.25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.border.withValues(alpha: 0.1),
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: widget.image,
            ),
          ),
        ),
        if (widget.expandContent)
          Expanded(
            child: Padding(
              padding:
                  widget.contentPadding ??
                  const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.sm,
                    0,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
              child: widget.content,
            ),
          )
        else
          Flexible(
            child: Padding(
              padding:
                  widget.contentPadding ??
                  const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.sm,
                    0,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
              child: widget.content,
            ),
          ),
      ],
    );
  }

  Widget _buildHorizontalLayout(DesignSystemColors colors) {
    return SizedBox(
      height: widget.horizontalHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xs2),
            child: SizedBox(
              width: widget.horizontalImageWidth,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.border.withValues(alpha: 0.1),
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: widget.image,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding:
                  widget.contentPadding ??
                  const EdgeInsetsDirectional.fromSTEB(
                    0,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
              child: widget.content,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildFallbackImage() {
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [
          AppColors.primary.withValues(alpha: 0.08),
          AppColors.primary.withValues(alpha: 0.15),
        ],
      ),
    ),
    child: const Center(
      child: Icon(Icons.school_outlined, color: AppColors.primary, size: 32),
    ),
  );
}

Widget _buildBaseImage(String thumbnailUrl, DesignSystemColors colors) {
  if (thumbnailUrl.trim().isEmpty) {
    return _buildFallbackImage();
  }
  return CachedNetworkImage(
    imageUrl: thumbnailUrl,
    cacheManager: AppImageCacheManager.instance,
    fit: BoxFit.cover,
    placeholder: (context, url) => Container(color: colors.surface2),
    errorWidget: (context, url, error) => _buildFallbackImage(),
  );
}

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
        _buildBaseImage(data.thumbnailUrl, colors),
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

    return _OverlayBadge(
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

class MyCourseCard extends StatelessWidget {
  final MyCourseVM data;
  final bool isHorizontal;
  final VoidCallback? onTap;

  const MyCourseCard({
    super.key,
    required this.data,
    this.isHorizontal = false,
    this.onTap,
  });

  void _defaultNavigation(BuildContext context) {
    context.push('/courses/${data.id}');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final imageWidget = _buildBaseImage(data.thumbnailUrl, colors);

    final contentWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.title,
          style: (isHorizontal ? AppTextStyles.bodyMedium : AppTextStyles.h4)
              .copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
                height: 1.15,
              ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const Spacer(),
        CourseCardProgressBar(
          progress: data.progress,
          totalLessons: data.totalLessons,
        ),
      ],
    );

    return CourseCardBase(
      image: imageWidget,
      content: contentWidget,
      isHorizontal: isHorizontal,
      semanticLabel: data.title,
      onTap: onTap ?? () => _defaultNavigation(context),
      verticalImageAspectRatio: 16 / 9,
      horizontalHeight: 80,
      // Square thumbnail in the horizontal layout (width == height) for
      // the My Courses list.
      horizontalImageWidth: 80,
      contentPadding: isHorizontal
          ? const EdgeInsetsDirectional.fromSTEB(
              0,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.xs,
            )
          : const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.sm,
              0,
              AppSpacing.sm,
              AppSpacing.md,
            ),
    );
  }
}

class RecentCourseCard extends StatelessWidget {
  final RecentCourseVM data;
  final VoidCallback? onTap;

  const RecentCourseCard({super.key, required this.data, this.onTap});

  void _defaultNavigation(BuildContext context) {
    context.push('/courses/${data.id}');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final imageWidget = _buildBaseImage(data.thumbnailUrl, colors);

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
        const Spacer(),
        CourseCardProgressBar(
          progress: data.progress,
          totalLessons: data.totalLessons,
        ),
      ],
    );

    return CourseCardBase(
      image: imageWidget,
      content: contentWidget,
      semanticLabel: data.title,
      onTap: onTap ?? () => _defaultNavigation(context),
      // Taller than the 16:9 used elsewhere (was 16/9) — this card only,
      // per request to increase RecentCourseCard height without affecting
      // MyCourseCard/DiscoverCourseCard, which set their own ratios.
      verticalImageAspectRatio: 16 / 9,
      expandContent: true,
      contentPadding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
      ),
    );
  }
}

class CourseCardProgressBar extends StatelessWidget {
  final double progress;
  final int totalLessons;

  const CourseCardProgressBar({
    super.key,
    required this.progress,
    required this.totalLessons,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    final safeProgress = progress.clamp(0.0, 1.0);
    final isCompleted = safeProgress >= 1.0;
    final completedLessons = isCompleted
        ? totalLessons
        : (safeProgress * totalLessons).round().clamp(0, totalLessons);
    final statusColor = isCompleted ? colors.success : colors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppProgressBar(progress: safeProgress),
        const SizedBox(height: AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              isCompleted ? l10n.completed : '${(safeProgress * 100).round()}%',
              style: AppTextStyles.labelSmall.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            Icon(
              isCompleted ? Icons.check_circle : Icons.play_circle_outline,
              size: 13,
              color: isCompleted ? colors.success : colors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs2),
            Text(
              l10n.lessonsProgress(completedLessons, totalLessons),
              style: AppTextStyles.labelSmall.copyWith(
                color: colors.textSecondary,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }
}

class DiscoverCourseCardShimmer extends StatelessWidget {
  final bool isHorizontal;
  const DiscoverCourseCardShimmer({super.key, this.isHorizontal = false});

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: DiscoverCourseCard(
        data: DiscoverCourseVM.skeleton(),
        isHorizontal: isHorizontal,
      ),
    );
  }
}

class MyCourseCardShimmer extends StatelessWidget {
  final bool isHorizontal;
  const MyCourseCardShimmer({super.key, this.isHorizontal = false});

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: MyCourseCard(
        data: MyCourseVM.skeleton(),
        isHorizontal: isHorizontal,
      ),
    );
  }
}

class RecentCourseCardShimmer extends StatelessWidget {
  const RecentCourseCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: RecentCourseCard(data: RecentCourseVM.skeleton()),
    );
  }
}

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
      duration: const Duration(seconds: 2),
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
              BoxShadow(
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
      child: _OverlayBadge(
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

class _OverlayBadge extends StatelessWidget {
  final Widget child;
  final Color? tint;

  const _OverlayBadge({required this.child, this.tint});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final badgeColor = tint ?? colors.surface;
    final borderColor = tint ?? colors.border;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: AppSpacing.xs, sigmaY: AppSpacing.xs),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: borderColor.withValues(alpha: 0.32)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs2,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
