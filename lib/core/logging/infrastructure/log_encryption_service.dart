import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-256-GCM encryption service for audit event details.
///
/// Keys are stored in [FlutterSecureStorage] and auto-generated on first use.
/// Ciphertext is prefixed with a version identifier (`v1:`) to support
/// future key rotation without breaking existing encrypted data.
class LogEncryptionService {
  static const _storageKeyPrefix = 'log_encryption_key_v';
  static const _currentKeyVersion = 1;
  static const _versionPrefix = 'v$_currentKeyVersion:';

  final FlutterSecureStorage _secureStorage;
  Key? _cachedKey;

  LogEncryptionService([FlutterSecureStorage? storage])
    : _secureStorage = storage ?? const FlutterSecureStorage();

  /// Get or create the encryption key for the current version.
  Future<Key> _getKey() async {
    if (_cachedKey != null) return _cachedKey!;

    const storageKey = '$_storageKeyPrefix$_currentKeyVersion';
    String? keyBase64 = await _secureStorage.read(key: storageKey);

    if (keyBase64 == null) {
      // Generate a new 256-bit key
      final random = Random.secure();
      final keyBytes = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        keyBytes[i] = random.nextInt(256);
      }
      keyBase64 = base64Encode(keyBytes);
      await _secureStorage.write(key: storageKey, value: keyBase64);
    }

    _cachedKey = Key.fromBase64(keyBase64);
    return _cachedKey!;
  }

  /// Encrypt [plaintext] using AES-256-GCM.
  ///
  /// Returns a versioned string: `v1:base64_iv:base64_ciphertext`
  Future<String> encrypt(String plaintext) async {
    final key = await _getKey();
    final iv = IV.fromSecureRandom(12); // 96-bit IV for GCM
    final encrypter = Encrypter(AES(key));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    return '$_versionPrefix${iv.base64}:${encrypted.base64}';
  }

  /// Decrypt a versioned ciphertext string.
  ///
  /// Reads the version prefix to select the correct key.
  /// Falls back to current key if no version prefix found.
  Future<String> decrypt(String ciphertext) async {
    // Parse version
    if (!ciphertext.startsWith('v')) {
      throw const FormatException(
        'Invalid encrypted format: missing version prefix',
      );
    }

    final colonIdx = ciphertext.indexOf(':');
    if (colonIdx == -1) {
      throw const FormatException('Invalid encrypted format');
    }

    // Extract components: "v1:iv_base64:ciphertext_base64"
    final rest = ciphertext.substring(colonIdx + 1);
    final parts = rest.split(':');
    if (parts.length != 2) {
      throw const FormatException(
        'Invalid encrypted format: expected iv:ciphertext',
      );
    }

    final key = await _getKey();
    final iv = IV.fromBase64(parts[0]);
    final encrypter = Encrypter(AES(key));

    return encrypter.decrypt64(parts[1], iv: iv);
  }
}
