import 'dart:io';

import '../../../../core/network/supabase_client.dart';
import '../../../../core/services/encryption_service.dart';
import '../../../../core/utils/device_info_helper.dart';
import '../../data/datasources/download_local_ds.dart';

/// Why offline playback of a specific download was denied.
///
/// Each value is a direct, individually testable branch inside
/// [OfflinePolicyEngine.authorize] — this is the client-side approximation
/// of the "Security Invariants" list (P6.41) in
/// `EduZone_Offline_Download_Security_Trusted_Playback_Architecture.md`:
/// no valid/owned/un-expired/un-tampered download => no playback.
enum OfflinePlaybackDenialReason {
  downloadNotFound,
  notCompleted,
  expired,
  ownerMismatch,
  deviceMismatch,
  missingFile,
  missingKey,
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
      case OfflinePlaybackDenialReason.notCompleted:
        return 'This download has not finished yet.';
      case OfflinePlaybackDenialReason.expired:
        return "This offline download has expired. Reconnect and "
            "download it again.";
      case OfflinePlaybackDenialReason.ownerMismatch:
        return "This download belongs to a different account on this "
            "device and can't be played here.";
      case OfflinePlaybackDenialReason.deviceMismatch:
        return "This download is bound to a different device and can't "
            "be played here.";
      case OfflinePlaybackDenialReason.missingFile:
        return 'This download is missing or corrupted. Delete it and '
            'download it again.';
      case OfflinePlaybackDenialReason.missingKey:
        return 'This download can no longer be decrypted on this device. '
            'Delete it and download it again.';
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
/// against locally stored metadata plus a device-local AES-256-GCM key. It
/// does **not** implement a server-issued, cryptographically signed
/// license (P6.4), anti-replay protection (P6.25), or hardware-backed DRM.
/// A local attacker capable of tampering with both the app's SQLite
/// database and its secure storage together (T2 in the threat model —
/// root/jailbreak) could still defeat these checks. That is a real,
/// intentionally-documented limitation of client-only enforcement, not a
/// DRM-equivalence claim.
class OfflinePolicyEngine {
  OfflinePolicyEngine({
    required DownloadLocalDataSource localDataSource,
    required EncryptionService encryptionService,
    String Function()? deviceFingerprint,
    String? Function()? currentUserId,
  })  : _localDataSource = localDataSource,
        _encryptionService = encryptionService,
        _deviceFingerprint = deviceFingerprint ?? _defaultDeviceFingerprint,
        _currentUserId = currentUserId ?? _defaultCurrentUserId;

  final DownloadLocalDataSource _localDataSource;
  final EncryptionService _encryptionService;
  final String Function() _deviceFingerprint;
  final String? Function() _currentUserId;

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

    final status = row['download_status'] as String?;
    if (status != 'completed') {
      throw OfflinePlaybackDeniedException(
        OfflinePlaybackDenialReason.notCompleted,
        'downloadId=$downloadId status=$status', // check-ignore: dev-only debugDetail, never rendered — see userMessage
      );
    }

    final expiresAt = _asDateTime(row['expires_at']);
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

    if (ownerUserId == null && ownerDeviceId == null) {
      // Legacy download created before account/device binding existed
      // (pre schema-v7). Adopt it to the current account/device the first
      // time it is played, instead of retroactively invalidating content
      // the user already legitimately downloaded on this same install —
      // see the migration note in storage_service.dart. Best-effort: a
      // failure to persist the adoption must not block a play attempt
      // that was otherwise allowed.
      try {
        await _localDataSource.updateDownload(downloadId, {
          'user_id': currentUserId,
          'device_id': currentDeviceId,
        });
      } catch (_) {}
      return;
    }

    if (ownerUserId != null && ownerUserId != currentUserId) {
      throw OfflinePlaybackDeniedException(
        OfflinePlaybackDenialReason.ownerMismatch,
        'downloadId=$downloadId owner=$ownerUserId current=$currentUserId', // check-ignore: dev-only debugDetail, never rendered — see userMessage
      );
    }
    if (ownerDeviceId != null && ownerDeviceId != currentDeviceId) {
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
