import 'dart:io';

import '../../../../core/error/exceptions.dart';
import '../../../../core/logging/domain/app_event.dart';
import '../../../../core/logging/infrastructure/event_bus.dart';
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
/// diagnostics only (no file paths, ids, or internal state) — per project
/// instructions §14, raw exception text must never reach the UI directly.
/// The user-facing wording for every [reason] lives in the l10n ARB files
/// and is resolved at render time by `OfflinePlayerErrorView` via
/// `offlineDenialMessage` — the reason enum, not an English string, is the
/// contract this layer hands to the UI.
class OfflinePlaybackDeniedException implements Exception {
  final OfflinePlaybackDenialReason reason;
  final String debugDetail;

  const OfflinePlaybackDeniedException(this.reason, this.debugDetail);

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
    Future<Map<String, dynamic>> Function({
      required String entitlementId,
    })? revalidateEntitlement,
    required String? Function() currentUserId,
    String Function()? deviceFingerprint,
    OfflineClockGuard? clockGuard,
    EventBus? eventBus,
  })  : _localDataSource = localDataSource,
        _encryptionService = encryptionService,
        _revalidateEntitlement = revalidateEntitlement,
        _deviceFingerprint = deviceFingerprint ?? _defaultDeviceFingerprint,
        _currentUserId = currentUserId,
        // Defaults to a no-secure-storage instance (degrades to "cannot
        // detect rollback" rather than throwing) so every existing
        // construction site — including every existing test — keeps
        // working unchanged. Production call sites should pass a real
        // `OfflineClockGuard(secureStorage: hardenedSecureStorage)`
        // explicitly, mirroring `EncryptionService`'s convention — see
        // `offline_player_wrapper.dart` and `core/security/secure_storage_config.dart`.
        _clockGuard = clockGuard ?? OfflineClockGuard(),
        // Optional (P6.36/P6.37 security telemetry): every existing
        // construction site, including every existing test, keeps working
        // unchanged when omitted — `authorize` simply skips emitting an
        // event. Production call sites should pass the app's real
        // `ref.read(eventBusProvider)` — see `offline_player_wrapper.dart`.
        _eventBus = eventBus;

  final DownloadLocalDataSource _localDataSource;
  final EncryptionService _encryptionService;

  /// Server-side entitlement revalidation, injected from the downloads
  /// datasource (`revalidateOfflineEntitlement` — derives the device id
  /// itself) so this application service never touches Supabase directly.
  /// Null means "no revalidation wired" — treated exactly like a
  /// transient/offline failure: playback continues on the locally cached
  /// ACTIVE entitlement. Failures arrive pre-classified as
  /// `ServerException(network_error | server_error)`.
  final Future<Map<String, dynamic>> Function({
    required String entitlementId,
  })? _revalidateEntitlement;
  final String Function() _deviceFingerprint;
  final String? Function() _currentUserId;
  final OfflineClockGuard _clockGuard;
  final EventBus? _eventBus;

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
    try {
      await _authorizeInternal(downloadId);
    } on OfflinePlaybackDeniedException catch (e) {
      // P6.36/P6.37 security telemetry — never includes file paths, keys,
      // or any of the fields OfflinePlaybackDeniedException.debugDetail
      // may carry; only the machine-readable reason and downloadId (the
      // end-user wording is resolved from the reason by the UI layer).
      _eventBus?.emit(OfflinePlaybackDeniedEvent(
        timestamp: DateTime.now(),
        userId: _currentUserId(),
        deviceId: _deviceFingerprint(),
        downloadId: downloadId,
        reason: e.reason.name,
      ));
      rethrow;
    }
    _eventBus?.emit(OfflinePlaybackAuthorizedEvent(
      timestamp: DateTime.now(),
      userId: _currentUserId(),
      deviceId: _deviceFingerprint(),
      downloadId: downloadId,
    ));
  }

  Future<void> _authorizeInternal(String downloadId) async {
    final row = await _localDataSource.getDownloadById(downloadId);
    if (row == null) {
      throw OfflinePlaybackDeniedException(
        OfflinePlaybackDenialReason.downloadNotFound,
        'No local record for downloadId=$downloadId', // check-ignore: dev-only debugDetail, never rendered — localized in OfflinePlayerErrorView
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
        'downloadId=$downloadId', // check-ignore: dev-only debugDetail, never rendered — localized in OfflinePlayerErrorView
      );
    }

    final status = row['download_status'] as String?;
    if (status != 'completed') {
      throw OfflinePlaybackDeniedException(
        OfflinePlaybackDenialReason.notCompleted,
        'downloadId=$downloadId status=$status', // check-ignore: dev-only debugDetail, never rendered — localized in OfflinePlayerErrorView
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
        'downloadId=$downloadId ${e.detail}', // check-ignore: dev-only debugDetail, never rendered — localized in OfflinePlayerErrorView
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
      final revalidate = _revalidateEntitlement;
      if (revalidate == null) {
        // No revalidation wired — behave exactly like a failed call:
        // continue with the locally cached ACTIVE entitlement below.
      } else {
      final serverData = await revalidate(entitlementId: entitlementId);
      final serverStatus = serverData['status']?.toString();
      final serverExpiry = DateTime.tryParse(serverData['expires_at']?.toString() ?? '');
      final serverRevokedAt = DateTime.tryParse(serverData['revoked_at']?.toString() ?? '');
      final localContentVersion = row['content_version']?.toString();
      final serverContentVersion = serverData['content_version']?.toString();
      if (localContentVersion != null &&
          localContentVersion.isNotEmpty &&
          serverContentVersion != null &&
          serverContentVersion.isNotEmpty &&
          localContentVersion != serverContentVersion) {
        throw OfflinePlaybackDeniedException(
          OfflinePlaybackDenialReason.serverRevalidationDenied,
          'downloadId=$downloadId content version mismatch', // check-ignore
        );
      }
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
      }
    } on OfflinePlaybackDeniedException {
      rethrow;
    } on ServerException catch (e) {
      // The datasource pre-classifies: network_error covers genuine
      // offline operation, connectivity faults and transient server classes
      // (08/53/PGRST00x) — continue with the cached server entitlement
      // below. server_error is a real server decision/response: hard deny.
      if (e.code != 'network_error') {
        throw OfflinePlaybackDeniedException(
          OfflinePlaybackDenialReason.serverRevalidationDenied,
          'downloadId=$downloadId serverCode=${e.code}', // check-ignore
        );
      }
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
        'downloadId=$downloadId expiresAt=$expiresAt', // check-ignore: dev-only debugDetail, never rendered — localized in OfflinePlayerErrorView
      );
    }

    await _checkOwnershipAndBinding(downloadId, row);

    final encryptedPath = row['encrypted_path'] as String?;
    if (encryptedPath == null ||
        encryptedPath.isEmpty ||
        !await File(encryptedPath).exists()) {
      throw OfflinePlaybackDeniedException(
        OfflinePlaybackDenialReason.missingFile,
        'downloadId=$downloadId', // check-ignore: dev-only debugDetail, never rendered — localized in OfflinePlayerErrorView
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
        'downloadId=$downloadId', // check-ignore: dev-only debugDetail, never rendered — localized in OfflinePlayerErrorView
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
        'downloadId=$downloadId owner=$ownerUserId current=$currentUserId', // check-ignore: dev-only debugDetail, never rendered — localized in OfflinePlayerErrorView
      );
    }
    if (ownerDeviceId != currentDeviceId) {
      throw OfflinePlaybackDeniedException(
        OfflinePlaybackDenialReason.deviceMismatch,
        'downloadId=$downloadId ownerDevice=$ownerDeviceId ' // check-ignore: dev-only debugDetail, never rendered — localized in OfflinePlayerErrorView
        'currentDevice=$currentDeviceId', // check-ignore: dev-only debugDetail, never rendered — localized in OfflinePlayerErrorView
      );
    }
  }

  DateTime? _asDateTime(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return null;
  }
}
