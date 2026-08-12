import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';
import 'app_network_image.dart';
import 'app_thumbnail_fallback.dart';

/// A shared course thumbnail widget used in both [CoursePreviewScreen] and
/// [CourseDetailsScreen].
///
/// Displays [thumbnailUrl] via [AppNetworkImage] when available, and falls
/// back to [AppThumbnailFallback] when the URL is null or empty. This
/// eliminates the duplicated `if (thumbnailUrl != null) ... else ...` pattern
/// that previously existed in both screens.
class AppCourseThumbnail extends StatelessWidget {
  final String? thumbnailUrl;
  final DesignSystemColors ds;
  final BoxFit fit;
  final Alignment alignment;

  const AppCourseThumbnail({
    super.key,
    required this.thumbnailUrl,
    required this.ds,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return AppNetworkImage(
        url: thumbnailUrl!,
        fit: fit,
        alignment: alignment,
      );
    }
    return AppThumbnailFallback(ds: ds);
  }
}
