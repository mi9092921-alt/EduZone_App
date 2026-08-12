import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../tokens/app_colors.dart';
import '../../tokens/app_radius.dart';
import '../../tokens/app_spacing.dart';

/// A unified Skeletonizer wrapper for the EduZone Design System.
/// This ensures consistent colors, animations, and shapes across all skeletons.
/// Uses shimmer effect for smooth, perceivable loading animations.
class AppSkeleton extends StatelessWidget {
  final Widget child;
  final bool enabled;
  final bool ignoreContainers;
  final Duration? shimmerDuration;
  final bool isSliver;

  const AppSkeleton({
    super.key,
    required this.child,
    this.enabled = true,
    this.ignoreContainers = false,
    this.shimmerDuration,
  }) : isSliver = false;

  const AppSkeleton.sliver({
    super.key,
    required this.child,
    this.enabled = true,
    this.ignoreContainers = false,
    this.shimmerDuration,
  }) : isSliver = true;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // High-contrast shimmer for better perceived performance
    final baseColor = isDark
        ? colors.surface2.withValues(alpha: 0.8)
        : colors.surface2.withValues(alpha: 0.6);

    final highlightColor = isDark
        ? colors.surface.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.8);

    final effect = ShimmerEffect(
      baseColor: baseColor,
      highlightColor: highlightColor,
      duration: shimmerDuration ?? const Duration(milliseconds: 1200),
    );

    final textBoneBorderRadius = TextBoneBorderRadius(
      BorderRadius.circular(AppRadius.sm),
    );

    if (isSliver) {
      return Skeletonizer.sliver(
        enabled: enabled,
        ignoreContainers: ignoreContainers,
        containersColor: baseColor,
        effect: effect,
        textBoneBorderRadius: textBoneBorderRadius,
        child: child,
      );
    }

    return RepaintBoundary(
      child: Skeletonizer(
        enabled: enabled,
        ignoreContainers: ignoreContainers,
        containersColor: baseColor,
        effect: effect,
        textBoneBorderRadius: textBoneBorderRadius,
        // Pad placeholder bones for more realistic appearance
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: child,
        ),
      ),
    );
  }
}

/// A collection of static dummy data to be used in Skeletons.
class AppSkeletonData {
  static const String dummyTitle = 'Loading Course Title...';
  static const String dummyShortText = 'Loading...';
  static const String dummyLongText =
      'This is a longer placeholder text meant to fill space during the skeleton loading state...';
  static const String dummyCategory = 'CATEGORY';
}

/// Reusable skeleton placeholder for common UI patterns.
class AppSkeletonTile extends StatelessWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const AppSkeletonTile({
    super.key,
    this.height = 16,
    this.width,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.sm),
      ),
    );
  }
}
