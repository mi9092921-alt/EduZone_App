import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/cache/app_image_cache_manager.dart';

class AppAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double radius;

  const AppAvatar({
    super.key,
    this.url,
    required this.name,
    this.radius = 24.0,
  });

  String get _initials {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      // P8.10 fix: bound in-memory decode to the actual avatar diameter
      // (dpr-scaled) instead of decoding the source photo at full
      // resolution for a circle that may render at 24–40px radius.
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final decodeSize = (radius * 2 * dpr).round();

      return CachedNetworkImage(
        imageUrl: url!,
        cacheManager: AppImageCacheManager.instance,
        memCacheWidth: decodeSize,
        memCacheHeight: decodeSize,
        imageBuilder: (context, imageProvider) =>
            CircleAvatar(radius: radius, backgroundImage: imageProvider),
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          child: const CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) =>
            CircleAvatar(radius: radius, child: Text(_initials)),
      );
    }
    return CircleAvatar(radius: radius, child: Text(_initials));
  }
}
