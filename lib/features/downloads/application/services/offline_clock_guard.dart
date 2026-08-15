import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thrown by [OfflineClockGuard.checkAndRecord] when the device clock
/// appears to have moved backward far enough to suspect deliberate
/// manipulation (P6.16 — "Offline Clock Security" in
/// `EduZone_Offline_Download_Security_Trusted_Playback_Architecture.md`).
class ClockRollbackSuspectedException implements Exception {
  const ClockRollbackSuspectedException(this.detail);
  final String detail;

  @override
  String toString() => 'ClockRollbackSuspectedException($detail)';
}

/// Detects device-clock rollback for offline playback authorization.
///
/// [OfflinePolicyEngine.authorize]'s expiry check
/// (`DateTime.now().isAfter(expiresAt)`) has to trust the device clock —
/// there is no other clock available once the device is offline. Without
/// this guard, a user could defeat every offline expiry — regardless of
/// how it was originally set — simply by disconnecting from the network
/// and winding the device clock backward before each playback attempt
/// (T5 in the offline threat model: "مستخدم يفصل الإنترنت ويحاول
/// الاستمرار في الوصول للمحتوى إلى أجل غير محدد"). Detecting that does
/// not require network access, only that this app has previously observed
/// a later device time than it is seeing now.
///
/// **Honest security boundary**: this is a local, best-effort heuristic —
/// the same class of protection as the metadata HMAC signing in
/// `StorageService` (P6.22/P6.23), not a server-issued trusted-time
/// guarantee (P6.4, which this subsystem does not implement — see
/// `OfflinePolicyEngine`'s doc comment). The watermark is persisted in
/// secure storage (Keystore/Keychain-backed), not SQLite, so it can't be
/// edited by the same SQLite-browser tampering the sibling `tampered`
/// check defends against. A device that has never advanced its clock
/// while this app was installed, or one whose secure storage is itself
/// compromised (T2: root/jailbreak), is outside what this can catch.
class OfflineClockGuard {
  OfflineClockGuard({
    FlutterSecureStorage? secureStorage,
    this.tolerance = const Duration(hours: 6),
  }) : _secureStorage = secureStorage;

  static const _anchorKey = 'offline_clock_anchor_ms';

  final FlutterSecureStorage? _secureStorage;

  /// Absorbs legitimate small backward jumps (timezone changes, NTP
  /// correction, DST) without false-positives. Anything beyond this is
  /// treated as suspected manipulation.
  final Duration tolerance;

  /// Compares [now] (defaults to `DateTime.now()`) against the highest
  /// device time previously observed and persisted by this method.
  ///
  /// - If [now] is more than [tolerance] behind the stored watermark,
  ///   throws [ClockRollbackSuspectedException] and does **not** advance
  ///   the watermark.
  /// - Otherwise, advances the watermark to `max(watermark, now)` and
  ///   returns normally.
  ///
  /// Degrades to a no-op (never throws, never detects rollback) when no
  /// [FlutterSecureStorage] was supplied or it is unavailable at runtime
  /// — matching every other secure-storage-optional service in this
  /// subsystem (`EncryptionService`, `StorageService`): a missing backend
  /// means "can't verify", not "block playback".
  Future<void> checkAndRecord({DateTime? now}) async {
    final storage = _secureStorage;
    final current = now ?? DateTime.now();
    if (storage == null) return;

    String? storedRaw;
    try {
      storedRaw = await storage.read(key: _anchorKey);
    } catch (e) {
      debugPrint(
        '[OfflineClockGuard] degraded (secure storage read failed): '
        '${e.runtimeType}',
      );
      return;
    }

    final storedMs = storedRaw == null ? null : int.tryParse(storedRaw);
    if (storedMs != null) {
      final anchor = DateTime.fromMillisecondsSinceEpoch(storedMs);
      if (current.isBefore(anchor.subtract(tolerance))) {
        throw ClockRollbackSuspectedException(
          'device time $current is more than $tolerance behind the '
          'previously observed time $anchor',
        );
      }
      if (!current.isAfter(anchor)) {
        return; // No forward progress to persist.
      }
    }

    try {
      await storage.write(
        key: _anchorKey,
        value: current.millisecondsSinceEpoch.toString(),
      );
    } catch (e) {
      debugPrint(
        '[OfflineClockGuard] degraded (secure storage write failed): '
        '${e.runtimeType}',
      );
    }
  }
}
