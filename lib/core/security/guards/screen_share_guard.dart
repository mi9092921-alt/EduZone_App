part of '../security_service.dart';

class ScreenShareGuard {
  static const List<String> _kScreenShareBlacklist = [
    'com.teamviewer.teamviewer.market.mobile',
    'com.anydesk.anydeskandroid',
    'us.zoom.videomeetings',
    'com.microsoft.teams',
    'com.discord',
    'com.skype.raider',
    'com.google.android.apps.meetings',        // Google Meet
    'com.bandicam.android',                     // Bandicam recorder
    'com.nll.stf',                               // Screen Stream Mirroring
  ];

  /// Scans Android devices for known blacklisted screen sharing/casting packages.
  /// Skips on iOS due to platform sandboxing constraints.
  static Future<void> check() async {
    if (!Platform.isAndroid) return;

    try {
      final installedApps = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
      );

      for (final app in installedApps) {
        final packageName = app.packageName;
        if (_kScreenShareBlacklist.contains(packageName)) {
          SecurityService._onThreatDetected(
            'Blacklisted Screen Share App Active: $packageName',
          );
        }
      }
    } catch (_) {
      // Prevent blocking initialization if package scanning fails
    }
  }
}
