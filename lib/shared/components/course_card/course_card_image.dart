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
///
/// [context] is optional (kept nullable for source-compat with any other
/// callers outside this reviewed set) and, when supplied, is used to bound
/// in-memory decode size to [maxDecodeWidth] logical pixels scaled by the
/// device pixel ratio. Card thumbnails render at ~95-200 logical px wide
/// (see MyCourseCard/DiscoverCourseCard/RecentCourseCard call sites); CMS
/// thumbnails are frequently 1500px+. Without this bound, every card in a
/// scrolling grid/list decodes and keeps a full-resolution bitmap in the
/// Flutter image cache — a direct contributor to the "image memory" /
/// "unbounded cache" risk called out for course lists in the performance
/// and memory-safety docs. 480 is a conservative cap covering the widest
/// current usage (DiscoverCourseCard horizontal, 136px) at up to 3x DPR
/// with headroom, without needing per-call-site exact pixel plumbing.
Widget courseCardImage(
  String thumbnailUrl,
  DesignSystemColors colors, {
  BuildContext? context,
  double maxDecodeWidth = 480,
}) {
  if (thumbnailUrl.trim().isEmpty) {
    return courseCardFallbackImage();
  }
  final dpr = context != null
      ? MediaQuery.devicePixelRatioOf(context)
      : 2.0;
  final decodeWidth = (maxDecodeWidth * dpr).round();
  return CachedNetworkImage(
    imageUrl: thumbnailUrl,
    cacheManager: AppImageCacheManager.instance,
    memCacheWidth: decodeWidth,
    fit: BoxFit.cover,
    placeholder: (context, url) => Container(color: colors.surface2),
    errorWidget: (context, url, error) => courseCardFallbackImage(),
  );
}
