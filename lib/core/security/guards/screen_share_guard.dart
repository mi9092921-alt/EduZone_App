part of '../security_service.dart';

/// Returns the package names of the apps installed on the device.
///
/// Injectable so the matching and reporting logic is unit-testable off-device
/// (the real query needs an Android device).
typedef InstalledPackagesQuery = Future<Iterable<String>> Function();

/// Reports which known screen-share / remote-control packages are INSTALLED.
///
/// **This is telemetry, not protection.** A package being installed says
/// nothing about whether the screen is being shared or recorded — it is
/// present on the phones of most students (Discord, Zoom, Teams, Meet). Hits
/// are therefore reported to `security_incidents` as
/// `Screen Share App Installed: <package>` and NEVER terminate the app, block
/// login, or hide content (see [SecurityThreat.screenShareApp]). The previous
/// implementation reported `Blacklisted Screen Share App Active: <package>`
/// and routed it through the kill switch, which both mislabelled the signal
/// and could lock a legitimate student out.
///
/// The real protection against screen capture and casting is `FLAG_SECURE`,
/// set natively in `MainActivity.kt` and re-asserted by `ScreenshotGuard`.
///
/// Matching is EXACT package-name equality (never a substring), and there is
/// no cache: every [check] re-queries the device, so an uninstalled app is
/// not reported.
///
/// Note: on Android 11+ the query only sees other apps when the merged
/// manifest declares package visibility (`QUERY_ALL_PACKAGES` or `<queries>`).
/// Google Play restricts `QUERY_ALL_PACKAGES`; re-evaluate this guard before
/// a store build.
class ScreenShareGuard {
  static const List<String> _kScreenShareBlacklist = [
    'com.teamviewer.teamviewer.market.mobile',
    'com.anydesk.anydeskandroid',
    'us.zoom.videomeetings',
    'com.microsoft.teams',
    'com.discord',
    'com.skype.raider',
    'com.google.android.apps.meetings', // Google Meet
    'com.bandicam.android', // Bandicam recorder
    'com.nll.stf', // Screen Stream Mirroring
  ];

  /// Blacklisted packages present in [installed]. Exact match only; result
  /// follows blacklist order and contains no duplicates.
  static List<String> matchBlacklisted(Iterable<String> installed) {
    final present = installed.toSet();
    return [
      for (final package in _kScreenShareBlacklist)
        if (present.contains(package)) package,
    ];
  }

  static Future<Iterable<String>> _queryInstalledPackages() async {
    final installedApps = await InstalledApps.getInstalledApps(
      excludeSystemApps: false,
    );
    return installedApps.map((app) => app.packageName).whereType<String>();
  }

  /// Scans Android devices for known blacklisted screen sharing/casting
  /// packages. Skips on iOS due to platform sandboxing constraints.
  ///
  /// [query] and [isAndroid] exist for tests; production callers pass
  /// neither.
  static Future<void> check({
    InstalledPackagesQuery? query,
    bool? isAndroid,
  }) async {
    if (!(isAndroid ?? Platform.isAndroid)) return;

    try {
      final installed = await (query ?? _queryInstalledPackages)();
      for (final package in matchBlacklisted(installed)) {
        await SecurityService._onThreatDetected(
          SecurityThreat.screenShareApp,
          subject: package,
          source: 'installed_package_query',
        );
      }
    } catch (_) {
      // Prevent blocking initialization if package scanning fails
    }
  }
}
