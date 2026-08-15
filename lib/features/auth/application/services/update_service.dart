import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../../../../core/utils/version_comparator.dart';
import '../../data/datasources/update_remote_ds.dart';
import '../../domain/entities/update_info.dart';

/// Orchestrates the full update check flow.
///
/// Responsibilities (single):
///   - Fetch config via [UpdateRemoteDataSource]
///   - Resolve platform-correct store URL
///   - Delegate version comparison to [AppVersionChecker]
///   - Return a typed [UpdateInfo] result
///
/// Auth logic is NOT here. The [Auth] notifier simply awaits this service
/// and acts on the result — clean separation of concerns.
class UpdateService {
  final UpdateRemoteDataSource _remote;

  UpdateService(UpdateRemoteDataSource remote) : _remote = remote;

  /// Runs the full check. Returns [UpdateInfo] with the appropriate status.
  ///
  /// Never throws — on any error it returns [UpdateStatus.upToDate] so the
  /// app can proceed normally (fail-safe: never block the user on a network
  /// error during update check).
  Future<UpdateInfo> checkForUpdate(String currentVersion) async {
    try {
      final config = await _remote.fetchConfig();

      final latestVersion = _str(config, 'latest_version', '1.0.0');
      final minVersion = _str(config, 'min_app_version', '1.0.0');
      final forceUpdateFlag = _bool(config, 'force_update', false);
      final message = _str(config, 'update_message', '');
      final storeUrl = _resolveStoreUrl(config);

      final result = AppVersionChecker.check(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        minVersion: minVersion,
        forceUpdateFlag: forceUpdateFlag,
        message: message,
        storeUrl: storeUrl,
      );

      return _toUpdateInfo(result);
    } catch (e) {
      // Fail-safe: network/parse errors should never block the user.
      debugPrint(
        '[UpdateService] Update check failed (non-critical): '
        '${e.runtimeType}',
      );
      return const UpdateInfo.upToDate(latestVersion: '0.0.0');
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Resolves the correct store URL based on the current platform.
  /// Falls back to support_link if platform-specific links are absent.
  String _resolveStoreUrl(Map<String, dynamic> config) {
    try {
      if (Platform.isAndroid) {
        final link = _str(config, 'store_link_android', '');
        if (link.isNotEmpty) return link;
      } else if (Platform.isIOS) {
        final link = _str(config, 'store_link_ios', '');
        if (link.isNotEmpty) return link;
      }
    } catch (_) {
      // Platform.isAndroid throws on web — safe to ignore
    }
    // Fallback: support_link (used until platform-specific links are added)
    return _str(config, 'support_link', '');
  }

  UpdateInfo _toUpdateInfo(AppVersionCheckResult result) {
    return UpdateInfo(
      status: switch (result.status) {
        VersionCheckStatus.forceUpdate => UpdateStatus.forceUpdate,
        VersionCheckStatus.optionalUpdate => UpdateStatus.optionalUpdate,
        VersionCheckStatus.upToDate => UpdateStatus.upToDate,
      },
      message: result.message,
      storeUrl: result.storeUrl,
      latestVersion: result.latestVersion,
    );
  }

  String _str(Map<String, dynamic> m, String key, String fallback) {
    final v = m[key];
    if (v == null) return fallback;
    // JSONB may return already-parsed String or a quoted String
    final s = v.toString().replaceAll('"', '').trim();
    return s.isEmpty ? fallback : s;
  }

  bool _bool(Map<String, dynamic> m, String key, bool fallback) {
    final v = m[key];
    if (v == null) return fallback;
    if (v is bool) return v;
    return v.toString().toLowerCase() == 'true';
  }
}
