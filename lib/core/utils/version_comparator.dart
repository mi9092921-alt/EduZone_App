/// Semantic version comparator — safe against all common version formats.
///
/// Supports: "1.0", "1.0.0", "1.0.0+5", "1.0.0-beta"
/// Returns: negative if v1 < v2, 0 if equal, positive if v1 > v2
int compareVersions(String v1, String v2) {
  final reg = RegExp(r'\d+');

  final a = reg.allMatches(v1).map((e) => int.parse(e.group(0)!)).toList();
  final b = reg.allMatches(v2).map((e) => int.parse(e.group(0)!)).toList();

  final length = a.length > b.length ? a.length : b.length;

  for (int i = 0; i < length; i++) {
    final ai = i < a.length ? a[i] : 0;
    final bi = i < b.length ? b[i] : 0;
    if (ai != bi) return ai.compareTo(bi);
  }
  return 0;
}

/// Stateless checker — derives [UpdateInfo] from raw config values.
///
/// Called by [UpdateService] after fetching config from Supabase.
/// Pure function — no side effects, easy to unit test.
class AppVersionChecker {
  const AppVersionChecker._();

  /// Decision logic (matches the spec exactly):
  ///
  /// 1. current < min → force update (regardless of force_update flag)
  /// 2. current < latest + force_update == true → force update
  /// 3. current < latest + force_update == false → optional update
  /// 4. current >= latest → up to date
  static AppVersionCheckResult check({
    required String currentVersion,
    required String latestVersion,
    required String minVersion,
    required bool forceUpdateFlag,
    required String message,
    required String storeUrl,
  }) {
    if (compareVersions(currentVersion, minVersion) < 0) {
      return AppVersionCheckResult(
        status: VersionCheckStatus.forceUpdate,
        message: message,
        storeUrl: storeUrl,
        latestVersion: latestVersion,
      );
    }

    if (compareVersions(currentVersion, latestVersion) < 0) {
      return AppVersionCheckResult(
        status: forceUpdateFlag
            ? VersionCheckStatus.forceUpdate
            : VersionCheckStatus.optionalUpdate,
        message: message,
        storeUrl: storeUrl,
        latestVersion: latestVersion,
      );
    }

    return AppVersionCheckResult(
      status: VersionCheckStatus.upToDate,
      message: '',
      storeUrl: '',
      latestVersion: latestVersion,
    );
  }
}

enum VersionCheckStatus { upToDate, optionalUpdate, forceUpdate }

class AppVersionCheckResult {
  final VersionCheckStatus status;
  final String message;
  final String storeUrl;
  final String latestVersion;

  const AppVersionCheckResult({
    required this.status,
    required this.message,
    required this.storeUrl,
    required this.latestVersion,
  });
}
