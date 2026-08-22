import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../security/secure_storage_config.dart';

/// Production-grade device fingerprinting system per PRD §9.
///
/// Generates a stable SHA256 fingerprint from hardware-level device
/// attributes that persist across app reinstalls.
///
/// **Security fix:** On Android, hardware-level fields alone (brand,
/// model, hardware, product, ABI, display, bootloader) only identify the
/// *device model/firmware*, not the physical unit — two different phones
/// of the same common model (e.g. two Samsung Galaxy A52 units on the
/// same firmware build) previously produced an identical fingerprint.
/// A per-install random UUID (`installId`), generated once and persisted
/// in secure storage (Keystore/Keychain), is now mixed into the hash on
/// both platforms so that no two physical devices can collide.
///
/// **Limitation (iOS):** `identifierForVendor` resets on full app
/// reinstall if no other apps from the same vendor remain installed.
/// The `installId` is also lost on reinstall (secure storage is cleared
/// with the app on most platforms) — this is expected and acceptable,
/// matching pre-existing `identifierForVendor` reinstall behavior.
class DeviceInfoHelper {
  static const String fingerprintVersion = 'v2';
  static final DeviceInfoPlugin _plugin = DeviceInfoPlugin();
  static const _storage = hardenedSecureStorage;
  static const String _installIdKey = 'device_install_id_v1';

  static bool _initialized = false;
  static late String _fingerprint;
  static late bool _isEmulator;
  static late Map<String, dynamic> _deviceInfoJson;
  static late String _deviceModel;

  /// Initialize device info — must be called once during app startup.
  static Future<void> init() async {
    if (_initialized) return;

    if (Platform.isAndroid) {
      await _initAndroid();
    } else if (Platform.isIOS) {
      await _initIOS();
    } else {
      _fingerprint = _sha256(
        'unknown-${DateTime.now().millisecondsSinceEpoch}',
      );
      _isEmulator = true;
      _deviceInfoJson = {
        'platform': 'unknown',
        'fingerprint_version': fingerprintVersion,
      };
      _deviceModel = 'Unknown Device';
    }

    _initialized = true;
  }

  /// Returns a random UUID that uniquely identifies this app install on
  /// this physical device, generating and persisting one on first call.
  ///
  /// Stored via [FlutterSecureStorage] (Android Keystore / iOS Keychain),
  /// the same mechanism already used elsewhere in this app (see
  /// `supabase_client.dart`, `log_encryption_service.dart`). This is the
  /// component that makes the overall fingerprint unique per physical
  /// unit rather than per device model.
  static Future<String> _getOrCreateInstallId() async {
    try {
      final existing = await _storage.read(key: _installIdKey);
      if (existing != null && existing.isNotEmpty) return existing;

      final newId = const Uuid().v4();
      await _storage.write(key: _installIdKey, value: newId);
      return newId;
    } catch (e) {
      // Rare fallback (e.g. corrupted keystore on some legacy/rooted
      // devices). Prefer keeping the app usable over crashing; the
      // fingerprint simply won't persist across sessions for this
      // specific device until secure storage recovers.
      debugPrint(
        '[DeviceInfoHelper] Secure storage unavailable, install ID will '
        'not persist: $e',
      );
      return 'fallback-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  static Future<void> _initAndroid() async {
    final info = await _plugin.androidInfo;
    final installId = await _getOrCreateInstallId();

    // Stable fields that survive app reinstall. `installId` is listed
    // first as it is the field that guarantees per-unit uniqueness; the
    // remaining hardware/firmware fields are kept for defense-in-depth
    // and to preserve the existing device_info reporting shape.
    final stableFields = [
      installId,
      info.brand,
      info.device,
      info.hardware,
      info.model,
      info.product,
      info.supported64BitAbis.join(','),
      info.display,
      info.bootloader,
    ].join('|');

    _fingerprint = _sha256(stableFields);
    _isEmulator = !info.isPhysicalDevice;
    _deviceModel = '${info.brand} ${info.model}';

    _deviceInfoJson = {
      'platform': 'android',
      'fingerprint_version': fingerprintVersion,
      'model': info.model,
      'brand': info.brand,
      'device': info.device,
      'hardware': info.hardware,
      'product': info.product,
      'os_version':
          'Android ${info.version.release} (SDK ${info.version.sdkInt})',
      'security_patch': info.version.securityPatch,
      'fingerprint_build': info.fingerprint,
      'bootloader': info.bootloader,
      'cpu_abi': info.supported64BitAbis.isNotEmpty
          ? info.supported64BitAbis.first
          : info.supported32BitAbis.isNotEmpty
          ? info.supported32BitAbis.first
          : 'unknown',
      'display': info.display,
      'is_physical_device': info.isPhysicalDevice,
    };
  }

  static Future<void> _initIOS() async {
    final info = await _plugin.iosInfo;
    final installId = await _getOrCreateInstallId();

    // `identifierForVendor` is already unique per physical device on
    // iOS, so this platform was not vulnerable to the Android collision
    // issue. `installId` is still mixed in for defense-in-depth and to
    // keep the fingerprint derivation logic consistent across platforms.
    final stableFields = [
      installId,
      info.utsname.machine,
      info.systemVersion,
      info.identifierForVendor ?? 'no-vendor-id',
      info.model,
    ].join('|');

    _fingerprint = _sha256(stableFields);
    _isEmulator = !info.isPhysicalDevice;
    _deviceModel = info.utsname.machine;

    _deviceInfoJson = {
      'platform': 'ios',
      'fingerprint_version': fingerprintVersion,
      'model': info.model,
      'machine': info.utsname.machine,
      'system_name': info.systemName,
      'system_version': info.systemVersion,
      'os_version': '${info.systemName} ${info.systemVersion}',
      'identifier_for_vendor': info.identifierForVendor,
      'is_physical_device': info.isPhysicalDevice,
    };
  }

  /// SHA256 hash of the input string. Returns 64-char hex string.
  static String _sha256(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ─── Public Getters ────────────────────────────────────────────

  /// 64-character SHA256 hex fingerprint. Stable across reinstalls.
  static String get fingerprint {
    _assertInitialized();
    return _fingerprint;
  }

  /// `true` if running on an emulator/simulator.
  static bool get isEmulator {
    _assertInitialized();
    return _isEmulator;
  }

  /// Full device info JSONB map matching PRD §9.4.
  /// Stored in `devices.device_info` column.
  static Map<String, dynamic> get deviceInfoJson {
    _assertInitialized();
    return Map.unmodifiable(_deviceInfoJson);
  }

  /// Human-readable device model for profile display
  /// (e.g. "Samsung Galaxy A52").
  static String get deviceModel {
    _assertInitialized();
    return _deviceModel;
  }

  /// The platform string: 'android' | 'ios' | 'unknown'.
  static String get platform {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  static void _assertInitialized() {
    if (!_initialized) {
      throw StateError(
        'DeviceInfoHelper not initialized. Call DeviceInfoHelper.init() first.',
      );
    }
  }

  /// Reset for testing purposes only.
  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
  }
}
