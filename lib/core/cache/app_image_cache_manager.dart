import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Shared disk-cache policy for every network image in the app
/// (course thumbnails, avatars, instructor photos, ...).
///
/// Without an explicit [CacheManager], `cached_network_image` falls back to
/// its default config (200 objects / 30 days, effectively unbounded on
/// disk for an image-heavy course catalog). This gives the app one
/// explicit, tunable policy instead.
///
/// Usage: pass `cacheManager: AppImageCacheManager.instance` to every
/// `CachedNetworkImage` (already wired into `AppNetworkImage`, `AppAvatar`,
/// and `course_card.dart`).
class AppImageCacheManager {
  AppImageCacheManager._();

  static const key = 'eduZoneImageCache';

  /// How long a cached image is considered fresh before being re-validated
  /// against the network (course covers/avatars change infrequently).
  static const stalePeriod = Duration(days: 14);

  /// Upper bound on the number of cached image files kept on disk.
  /// Oldest entries are evicted first once this is exceeded.
  static const maxNrOfCacheObjects = 300;

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: stalePeriod,
      maxNrOfCacheObjects: maxNrOfCacheObjects,
    ),
  );
}
