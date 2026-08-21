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
    // P8.10/P8.11 fix: without memCacheWidth/Height, CachedNetworkImage
    // decodes the source image at its full resolution (course thumbnails
    // and instructor photos from the CMS are frequently 1500px+) even
    // though this widget only ever renders it into a `width`x`height` box.
    // That wastes decode CPU and — more importantly — image-cache memory
    // proportional to the *source* resolution, not the display resolution.
    // We already know our target box here, so bound the decode to it
    // (scaled by device pixel ratio so it still looks sharp on Xhdpi/3x
    // screens). `.round()` avoids handing flutter_cache_manager a
    // fractional-pixel cache key, which would otherwise fragment the disk
    // cache into near-duplicate entries per device density.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decodeWidth = width != null ? (width! * dpr).round() : null;
    final decodeHeight = height != null ? (height! * dpr).round() : null;

    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: AppImageCacheManager.instance,
      width: width,
      height: height,
      memCacheWidth: decodeWidth,
      memCacheHeight: decodeHeight,
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
