import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/cache/app_image_cache_manager.dart';
import '../../../design_system/design_system.dart';

/// Fallback artwork shown when a course has no thumbnail, or when the
/// network image fails to load.
///
/// Exposed (not `_`-prefixed) because it is used across multiple files in
/// this feature folder ([courseCardImage]). It stays out of the public
/// barrel export (`course_card.dart`) and out of the design system, so it
/// is only reachable from within `lib/shared/components/course_card/`.
Widget courseCardFallbackImage() {
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

/// Builds the cached network thumbnail used by every course card variant,
/// falling back to [courseCardFallbackImage] when there is no URL or the
/// image fails to load.
Widget courseCardImage(String thumbnailUrl, DesignSystemColors colors) {
  if (thumbnailUrl.trim().isEmpty) {
    return courseCardFallbackImage();
  }
  return CachedNetworkImage(
    imageUrl: thumbnailUrl,
    cacheManager: AppImageCacheManager.instance,
    fit: BoxFit.cover,
    placeholder: (context, url) => Container(color: colors.surface2),
    errorWidget: (context, url, error) => courseCardFallbackImage(),
  );
}
