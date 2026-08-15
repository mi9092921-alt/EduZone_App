import 'package:flutter/foundation.dart';

import '../../../../core/services/device_service.dart';
import '../../data/datasources/auth_remote_ds.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/usecases/bind_device.dart';

/// Refreshes device-binding, activity, and session tracking after a login
/// or a cold-start session resume.
///
/// Extracted from the `Auth` notifier's private `_syncActivityAndSession`
/// method (`auth_provider.dart`) so it can be constructed with plain
/// dependencies and unit-tested with mocktail, the same way
/// `LogoutOrchestrator` and `CheckUserAccessService` already are — instead
/// of only being reachable through the full Riverpod notifier + Supabase
/// stack.
///
/// This is a best-effort background sync: any failure here is logged and
/// swallowed rather than propagated, matching the original behavior —
/// activity/session tracking must never block or fail the auth flow that
/// triggered it.
class AuthActivitySyncService {
  final AuthRemoteDataSource _remoteDataSource;
  final DeviceService _deviceService;
  final BindDevice _bindDevice;

  const AuthActivitySyncService({
    required AuthRemoteDataSource remoteDataSource,
    required DeviceService deviceService,
    required BindDevice bindDevice,
  })  : _remoteDataSource = remoteDataSource,
        _deviceService = deviceService,
        _bindDevice = bindDevice;

  /// - [skipBind]: true when the calling flow (login, or device
  ///   re-validation on cold start) has already bound/re-bound the device
  ///   itself. When true, this also skips `recordSession` to avoid
  ///   flooding the sessions table on every app resume — a session row is
  ///   only recorded on a genuinely fresh login.
  Future<void> syncActivityAndSession(
    AppUser user, {
    bool skipBind = false,
  }) async {
    try {
      final fingerprint = _deviceService.fingerprint;

      if (!skipBind) {
        await _bindDevice(
          fingerprint,
          _deviceService.deviceInfoJson,
          _deviceService.platform,
        );
      }

      await _remoteDataSource.syncUserActivity(
        userId: user.id,
        tenantId: user.tenantId,
        deviceFingerprint: fingerprint,
      );

      if (!skipBind) {
        await _remoteDataSource.recordSession(
          userId: user.id,
          tenantId: user.tenantId,
          deviceFingerprint: fingerprint,
          regionId: user.regionId,
          userAgent:
              '${_deviceService.platform}: ${_deviceService.deviceInfoJson['model'] ?? 'Unknown'}',
        );
      }
    } catch (e) {
      debugPrint(
        '[AuthActivitySyncService] Background sync error: ${e.runtimeType}',
      );
    }
  }
}
