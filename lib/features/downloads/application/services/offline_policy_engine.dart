import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client.dart';
import '../../../../core/services/encryption_service.dart';
import '../../../../core/utils/device_info_helper.dart';
import '../../data/datasources/download_local_ds.dart';
import 'offline_clock_guard.dart';

/// Why offline playback of a specific download was denied.
///
/// Each value is a direct, individually testable branch inside
/// [OfflinePolicyEngine.authorize] — this is the client-side approximation
/// of the "Security Invariants" list (P6.41) in
/// `EduZone_Offline_Download_Security_Trusted_Playback_Architecture.md`:
/// no valid/owned/un-expired/un-tampered download => no playback.
enum OfflinePlaybackDenialReason {
  downloadNotFound,
  tampered,
  notCompleted,
  expired,
  ownerMismatch,
  deviceMismatch,
  missingFile,
  missingKey,
  clockRollbackSuspected,
  serverRevalidationDenied,
}

/// Thrown by [OfflinePolicyEngine.authorize] when offline playback is not
/// allowed.
///
/// Carries a machine-readable [reason] plus [debugDetail] for logs/
/// diagnostics, and a separate [userMessage] that is safe to show to end
/// users (no file paths, ids, or internal state) — per project
/// instructions §14, raw exception text must never reach the UI directly.
class OfflinePlaybackDeniedException implements Exception {
  final OfflinePlaybackDenialReason reason;
  final String debugDetail;

  const OfflinePlaybackDeniedException(this.reason, this.debugDetail);

  /// Whether [userMessage] is safe to show even in release builds. All
  /// current reasons are — none of them leak anything beyond "this
  /// download can't play right now and here's the generic reason why".
  bool get isSafeForRelease => true;

  String get userMessage {
    switch (reason) {
      case OfflinePlaybackDenialReason.downloadNotFound:
        return 'This download is no longer available.';
      case OfflinePlaybackDenialReason.tampered:
        return 'This download can no longer be verified and must be '
            'downloaded again.';
      case OfflinePlaybackDenialReason.notCompleted:
        return 'This download has not finished yet.';
      case OfflinePlaybackDenialReason.expired:
        return 'This offline download has expired. Reconnect and '
            'download it again.';
      case OfflinePlaybackDenialReason.ownerMismatch:
        return 'This download belongs to a different account on this '
            "device and can't be played here.";
      case OfflinePlaybackDenialReason.deviceMismatch:
        return "This download is bound to a different device and can't "
            'be played here.';
      case OfflinePlaybackDenialReason.missingFile:
        return 'This download is missing or corrupted. Delete it and '
            'download it again.';
      case OfflinePlaybackDenialReason.missingKey:
        return 'This download can no longer be decrypted on this device. '
            'Delete it and download it again.';
      case OfflinePlaybackDenialReason.clockRollbackSuspected:
        return "This device's clock appears to have changed. Reconnect to "
            'the internet and try again.';
      case OfflinePlaybackDenialReason.serverRevalidationDenied:
        return 'This offline download is no longer authorized. Reconnect and download it again.';
    }
  }

  @override
  String toString() =>
      'OfflinePlaybackDeniedException(${reason.name}): $debugDetail';
}

/// Central authorization gate for offline playback (P6.15).
///
/// No screen or widget decides on its own whether a decrypted stream may
/// be handed to the player — every attempt to start offline playback must
/// call [authorize] first (see `offline_player_wrapper.dart`) and treat a
/// thrown [OfflinePlaybackDeniedException] as a hard stop.
///
/// **Honest security boundary** (documented per project instructions §12
/// and P6.50 of the architecture doc): this engine enforces status /
/// expiry / account-binding / device-binding / integrity-presence checks
/// against locally stored metadata plus a device-local AES-256-GCM key.
/// Since schema v8, the security-critical fields (status, expiry, account
/// and device binding) are also HMAC-signed with a key that lives only in
/// secure storage (`StorageService`'s `security_signature` column) — so a
/// direct SQLite edit (T4: "مستخدم يحاول تعديل metadata") is detected as
/// [OfflinePlaybackDenialReason.tampered] rather than silently trusted.
/// Since this hardening pass, expiry is additionally guarded against
/// device-clock rollback (P6.16) via [OfflineClockGuard] — see its doc
/// comment for exactly what that does and does not catch.
///
/// This engine still does **not** implement a server-issued,
/// cryptographically signed license (P6.4) or anti-replay protection
/// (P6.25) — the HMAC key and clock watermark are device-generated and
/// device-held, not server-controlled, so together they raise the bar
/// against casual local tampering and clock manipulation but cannot
/// detect a fully compromised device that extracts the key/watermark
/// itself (T2 in the threat model — root/jailbreak). That remains a real,
/// intentionally-documented limitation of client-only enforcement, not a
/// DRM-equivalence claim.
class OfflinePolicyEngine {
  OfflinePolicyEngine({
    required DownloadLocalDataSource localDataSource,
    required EncryptionService encryptionService,
    String Function()? deviceFingerprint,
    String? Function()? currentUserId,
    OfflineClockGuard? clockGuard,
  })  : _localDataSource = localDataSource,
        _encryptionService = encryptionService,
        _deviceFingerprint = deviceFingerprint ?? _defaultDeviceFingerprint,
        _currentUserId = currentUserId ?? _defaultCurrentUserId,
        // Defaults to a no-secure-storage instance (degrades to "cannot
        // detect rollback" rather than throwing) so every existing
        // construction site — including every existing test — keeps
        // working unchanged. Production call sites should pass a real
        // `OfflineClockGuard(secureStorage: const FlutterSecureStorage())`
        // explicitly, mirroring `EncryptionService`'s convention — see
        // `offline_player_wrapper.dart`.
        _clockGuard = clockGuard ?? OfflineClockGuard();

  final DownloadLocalDataSource _localDataSource;
  final EncryptionService _encryptionService;
  final String Function() _deviceFingerprint;
  final String? Function() _currentUserId;
  final OfflineClockGuard _clockGuard;

  static String _defaultDeviceFingerprint() {
    try {
      return DeviceInfoHelper.fingerprint;
    } catch (_) {
      // DeviceInfoHelper.init() hasn't run yet — fail safe: this will never
      // match a stored device_id, so a bound download is correctly denied
      // rather than silently allowed.
      return '';
    }
  }

  static String? _defaultCurrentUserId() {
    try {
      return SupabaseService.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  /// Re-reads [downloadId] from the local database and enforces every
  /// invariant below. Returns normally when playback is allowed; throws
  /// [OfflinePlaybackDeniedException] otherwise.
  ///
  /// Deliberately re-reads from storage instead of trusting a
  /// possibly-stale in-memory `DownloadedLesson` passed around the UI —
  /// status/expiry/ownership can change (revocation, cleanup, account
  /// switch) between when the downloads list was last loaded and the
  /// moment the user taps play.
  Future<void> authorize(String downloadId) async {
    final row = await _localDataSource.getDownloadById(downloadId);
    if (row == null) {
      throw OfflinePlaybackDeniedException(
        OfflinePlaybackDenialReason.downloadNotFound,
        'No local record for downloadId=$downloadId', // check-ignore: dev-only debugDetail, never rendered — see userMessage
      );
    }

    // Tamper-evidence check (P6.22/P6.23) — must run before any of the
    // fields below are trusted for a decision. A signature mismatch means
    // something wrote to this row's security-critical fields outside this
    // app's own signing write path (e.g. direct SQLite edit on a rooted
    // device) — see StorageService.verifyDownloadSignature for exactly
    // what counts as a mismatch vs. a legitimate "not yet signed" row.
    final isIntact = await _localDataSource.verifyDownloadIntegrity(downloadId);
    if (!isIntact) {
      throw OfflinePlaybackDeniedException(
        OfflinePlaybackDenialReason.tampered,
        'downloadId=$downloadId', // check-ignore: dev-only debugDetail, never rendered — see userMessage
      );
    }

    final status = row['download_status'] as String?;
    if (status != 'completed') {
      throw OfflinePlaybackDeniedException(
        OfflinePlaybackDenialReason.notCompleted,
        'downloadId=$downloadId status=$status', // check-ignore: dev-only debugDetail, never rendered — see userMessage
      );
    }

    // Clock-rollback detection (P6.16) — must run before the expiry check
    // below, since that check is exactly what a rolled-back clock is used
    // to defeat. See OfflineClockGuard's doc comment for the honest
    // security boundary this provides.
    try {
      await _clockGuard.checkAndRecord();
    } on ClockRollbackSuspectedException catch (e) {
      throw OfflinePlaybackDeniedException(
        OfflinePlaybackDenialReason.clockRollbackSuspected,
        'downloadId=$downloadId ${e.detail}', // check-ignore: dev-only debugDetail, never rendered — see userMessage
      );
    }

    final entitlementId = row['entitlement_id']?.toString();
    final localServerStatus = row['server_status']?.toString();
    if (entitlementId == null || entitlementId.isEmpty || localServerStatus != 'ACTIVE') {
      throw OfflinePlaybackDeniedException(
        OfflinePlaybackDenialReason.serverRevalidationDenied,
        'downloadId=$downloadId missing/inactive server entitlement', // check-ignore
      );
    }

    // When the server is reachable, revalidate the authoritative entitlement.
    // If the device is actually offline, continue with the locally cached
    // ACTIVE entitlement and its fixed expiry. Any server-side deny is a hard
    // deny and updates local state before playback can continue.
    try {
      final serverData = await SupabaseService.client.rpc(
        'revalidate_offline_entitlement',
        params: {
          'p_entitlement_id': entitlementId,
          'p_device_id': _deviceFingerprint(),
        },
      );
      if (serverData is! Map<String, dynamic>) {
        throw const OfflinePlaybackDeniedException(
          OfflinePlaybackDenialReason.serverRevalidationDenied,
          'invalid server revalidation response', // check-ignore: dev-only debugDetail, never rendered — see userMessage
        );
      }
      final serverStatus = serverData['status']?.toString();
      final serverExpiry = DateTime.tryParse(serverData['expires_at']?.toString() ?? '');
      final serverRevokedAt = DateTime.tryParse(serverData['revoked_at']?.toString() ?? '');
      await _localDataSource.updateDownload(downloadId, {
        'server_status': serverStatus,
        'server_expires_at': serverExpiry?.millisecondsSinceEpoch,
        'server_revoked_at': serverRevokedAt?.millisecondsSinceEpoch,
      });
      if (serverStatus != 'ACTIVE' || serverExpiry == null) {
        throw OfflinePlaybackDeniedException(
          OfflinePlaybackDenialReason.serverRevalidationDenied,
          'downloadId=$downloadId serverStatus=$serverStatus', // check-ignore
        );
      }
    } on OfflinePlaybackDeniedException {
      rethrow;
    } on PostgrestException catch (e) {
      final code = e.code ?? '';
      final transient = code.startsWith('08') ||
          code.startsWith('53') ||
          code == 'PGRST000' ||
          code == 'PGRST001' ||
          code == 'PGRST002' ||
          code == 'PGRST003';
      if (!transient) {
        throw OfflinePlaybackDeniedException(
          OfflinePlaybackDenialReason.serverRevalidationDenied,
          'downloadId=$downloadId serverCode=$code', // check-ignore
        );
      }
    } on SocketException {
      // Genuine offline operation: use the cached server entitlement below.
    }

    final localExpiresAt = _asDateTime(row['expires_at']);
    final serverExpiresAt = _asDateTime(row['server_expires_at']);
    final expiresAt = localExpiresAt == null
        ? serverExpiresAt
        : serverExpiresAt == null
            ? localExpiresAt
            : (localExpiresAt.isBefore(serverExpiresAt) ? localExpiresAt : serverExpiresAt);
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      throw OfflinePlaybackDeniedException(
        OfflinePlaybackDenialReason.expired,
        'downloadId=$downloadId expiresAt=$expiresAt', // check-ignore: dev-only debugDetail, never rendered — see userMessage
      );
    }

    await _checkOwnershipAndBinding(downloadId, row);

    final encryptedPath = row['encrypted_path'] as String?;
    if (encryptedPath == null ||
        encryptedPath.isEmpty ||
        !await File(encryptedPath).exists()) {
      throw OfflinePlaybackDeniedException(
        OfflinePlaybackDenialReason.missingFile,
        'downloadId=$downloadId', // check-ignore: dev-only debugDetail, never rendered — see userMessage
      );
    }

    final expectedChecksum = row['checksum']?.toString();
    if (expectedChecksum == null || expectedChecksum.isEmpty) {
      throw OfflinePlaybackDeniedException(
        OfflinePlaybackDenialReason.tampered,
        'downloadId=$downloadId missing video integrity hash', // check-ignore
      );
    }
    final actualChecksum = await _encryptionService.calculateChecksum(File(encryptedPath));
    if (actualChecksum != expectedChecksum) {
      throw OfflinePlaybackDeniedException(
        OfflinePlaybackDenialReason.tampered,
        'downloadId=$downloadId video integrity mismatch', // check-ignore
      );
    }

    final audioPath = row['audio_path'] as String?;
    if (audioPath != null && audioPath.isNotEmpty) {
      final expectedAudioChecksum = row['audio_checksum']?.toString();
      if (expectedAudioChecksum == null || expectedAudioChecksum.isEmpty ||
          !await File(audioPath).exists()) {
        throw OfflinePlaybackDeniedException(
          OfflinePlaybackDenialReason.missingFile,
          'downloadId=$downloadId audio integrity metadata/file missing', // check-ignore
        );
      }
      final actualAudioChecksum = await _encryptionService.calculateChecksum(File(audioPath));
      if (actualAudioChecksum != expectedAudioChecksum) {
        throw OfflinePlaybackDeniedException(
          OfflinePlaybackDenialReason.tampered,
          'downloadId=$downloadId audio integrity mismatch', // check-ignore
        );
      }
    }

    String? key;
    try {
      key = await _encryptionService.retrieveKey(downloadId);
    } catch (_) {
      key = null;
    }
    if (key == null || key.isEmpty) {
      throw OfflinePlaybackDeniedException(
        OfflinePlaybackDenialReason.missingKey,
        'downloadId=$downloadId', // check-ignore: dev-only debugDetail, never rendered — see userMessage
      );
    }
  }

  Future<void> _checkOwnershipAndBinding(
    String downloadId,
    Map<String, dynamic> row,
  ) async {
    final ownerUserId = row['user_id'] as String?;
    final ownerDeviceId = row['device_id'] as String?;
    final currentUserId = _currentUserId();
    final currentDeviceId = _deviceFingerprint();

    if (ownerUserId == null || ownerDeviceId == null ||
        ownerUserId.isEmpty || ownerDeviceId.isEmpty ||
        currentUserId == null || currentDeviceId.isEmpty) {
      throw OfflinePlaybackDeniedException(
        OfflinePlaybackDenialReason.ownerMismatch,
        'downloadId=$downloadId unbound offline metadata', // check-ignore
      );
    }

    if (ownerUserId != currentUserId) {
      throw OfflinePlaybackDeniedException(
        OfflinePlaybackDenialReason.ownerMismatch,
        'downloadId=$downloadId owner=$ownerUserId current=$currentUserId', // check-ignore: dev-only debugDetail, never rendered — see userMessage
      );
    }
    if (ownerDeviceId != currentDeviceId) {
      throw OfflinePlaybackDeniedException(
        OfflinePlaybackDenialReason.deviceMismatch,
        'downloadId=$downloadId ownerDevice=$ownerDeviceId ' // check-ignore: dev-only debugDetail, never rendered — see userMessage
        'currentDevice=$currentDeviceId', // check-ignore: dev-only debugDetail, never rendered — see userMessage
      );
    }
  }

  DateTime? _asDateTime(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return null;
  }
}
