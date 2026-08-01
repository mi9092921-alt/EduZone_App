import 'package:flutter/widgets.dart';
import '../../../design_system/design_system.dart';

/// Supported card styles for the CourseCard UI platform.
enum CourseCardStyle { standard, compact, featured, preview }

/// Configuration object defining the layout and visibility properties for each card variant.
/// Designed for ultimate flexibility and run-time customization (Staff-Level).
class CourseCardVariantConfig {
  final double imageRatio;
  final EdgeInsets padding;
  final bool showMetadata;
  final bool showDescription;
  final bool showEnroll;
  final bool isHorizontal;
  final double? width;
  final double? height;
  final bool showPrice;
  final bool showStatus;
  final bool showFeaturedBadge;

  const CourseCardVariantConfig({
    required this.imageRatio,
    required this.padding,
    this.showMetadata = true,
    this.showDescription = false,
    this.showEnroll = false,
    this.isHorizontal = false,
    this.width,
    this.height,
    this.showPrice = true,
    this.showStatus = true,
    this.showFeaturedBadge = true,
  });

  CourseCardVariantConfig copyWith({
    double? imageRatio,
    EdgeInsets? padding,
    bool? showMetadata,
    bool? showDescription,
    bool? showEnroll,
    bool? isHorizontal,
    double? width,
    double? height,
    bool? showPrice,
    bool? showStatus,
    bool? showFeaturedBadge,
  }) {
    return CourseCardVariantConfig(
      imageRatio: imageRatio ?? this.imageRatio,
      padding: padding ?? this.padding,
      showMetadata: showMetadata ?? this.showMetadata,
      showDescription: showDescription ?? this.showDescription,
      showEnroll: showEnroll ?? this.showEnroll,
      isHorizontal: isHorizontal ?? this.isHorizontal,
      width: width ?? this.width,
      height: height ?? this.height,
      showPrice: showPrice ?? this.showPrice,
      showStatus: showStatus ?? this.showStatus,
      showFeaturedBadge: showFeaturedBadge ?? this.showFeaturedBadge,
    );
  }

  /// Default configuration for the 'Standard' style.
  static CourseCardVariantConfig standard() => const CourseCardVariantConfig(
    imageRatio: 16 / 9,
    padding: EdgeInsets.all(AppSpacing.md),
  );

  /// Default configuration for the 'Compact' style.
  static CourseCardVariantConfig compact() => const CourseCardVariantConfig(
    imageRatio: 4 / 3,
    padding: EdgeInsets.all(AppSpacing.sm),
    isHorizontal: true,
    height: 100, // AppSizes.courseCardCompactHeight
  );

  /// Default configuration for the 'Featured' style.
  static CourseCardVariantConfig featured() => const CourseCardVariantConfig(
    imageRatio: 21 / 9,
    padding: EdgeInsets.all(AppSpacing.lg),
    showDescription: true,
    showEnroll: true,
  );

  /// Default configuration for the 'Preview' style (Horizontal scroll lists).
  static CourseCardVariantConfig preview() => const CourseCardVariantConfig(
    imageRatio: 16 / 9,
    padding: EdgeInsets.all(AppSpacing.md),
    width: 180, // AppSizes.courseCardWidth
    height: 220,
    showPrice: false,
  );

  /// Factory-like mapper to get config by style.
  static CourseCardVariantConfig get(CourseCardStyle style) {
    switch (style) {
      case CourseCardStyle.compact:
        return compact();
      case CourseCardStyle.featured:
        return featured();
      case CourseCardStyle.preview:
        return preview();
      default:
        return standard();
    }
  }
}
