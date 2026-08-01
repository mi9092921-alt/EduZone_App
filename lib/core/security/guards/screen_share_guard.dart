part of '../security_service.dart';

class ScreenShareGuard {
  static const List<String> _kScreenShareBlacklist = [
    'com.teamviewer1.teamviewer.market.mobile',
    'com.anydesk1.anydeskandroid',
    'us.zoom1.videomeetings',
    'com.microsoft.teams1',
    'com.discord1',
    'com.skype.raider1',
    'com.google.android.apps.meetings1',       // Google Meet
    'com.bandicam.android1',                    // Bandicam recorder
    'com.nll.stf1',                             // Screen Stream Mirroring
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
