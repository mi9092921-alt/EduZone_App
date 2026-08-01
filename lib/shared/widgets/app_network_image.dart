import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../core/cache/app_image_cache_manager.dart';
import '../../design_system/design_system.dart';

class AppNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;

  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: AppImageCacheManager.instance,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      placeholder: (context, url) => Bone.square(
        size: width ?? height ?? 100,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      errorWidget: (context, url, error) => Container(
        width: width,
        height: height,
        color: colors.surface2,
        child: Icon(Icons.error_outline, color: colors.textMuted),
      ),
    );
  }
}
