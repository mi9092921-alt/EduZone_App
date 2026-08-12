// Additional coverage for EncryptionService that isn't in
// test/core/services/encryption_service_test.dart or
// test/core/encryption_index_test.dart.
//
// Focus: key lifecycle (secure storage), tamper/auth-tag detection,
// wrong-key failure, small-buffer (encryptBytes/decryptBytes) paths,
// malformed/truncated file handling, and the null-storage guard clauses.
//
// Copy to: test/core/services/encryption_service_security_test.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app/core/services/encryption_service.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('key lifecycle via secure storage', () {
    late EncryptionService service;
    late MockFlutterSecureStorage storage;

    setUp(() {
      storage = MockFlutterSecureStorage();
      service = EncryptionService(storage);
    });

    test('storeKey writes under the enc_key_ prefixed key', () async {
      when(() => storage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      await service.storeKey('download-42', 'some-base64-key');

      verify(() => storage.write(
            key: 'enc_key_download-42',
            value: 'some-base64-key',
          )).called(1);
    });

    test('retrieveKey reads under the enc_key_ prefixed key and returns it',
        () async {
      when(() => storage.read(key: 'enc_key_download-42'))
          .thenAnswer((_) async => 'stored-key');

      final result = await service.retrieveKey('download-42');

      expect(result, 'stored-key');
      verify(() => storage.read(key: 'enc_key_download-42')).called(1);
    });

    test('retrieveKey returns null when the key does not exist', () async {
      when(() => storage.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);

      final result = await service.retrieveKey('missing-download');

      expect(result, isNull);
    });

    test('deleteKey removes under the enc_key_ prefixed key', () async {
      when(() => storage.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});

      await service.deleteKey('download-42');

      verify(() => storage.delete(key: 'enc_key_download-42')).called(1);
    });

    test('storeKey/retrieveKey/deleteKey throw StateError without storage',
        () async {
      final serviceWithoutStorage = EncryptionService();

      // storeKey/retrieveKey/deleteKey are `async` methods, so even their
      // early `if (_secureStorage == null) throw ...` guard is delivered as
      // a rejected Future, not a synchronous throw — assert against the
      // Future directly via expectLater rather than wrapping in a closure.
      await expectLater(
        serviceWithoutStorage.storeKey('id', 'key'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        serviceWithoutStorage.retrieveKey('id'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        serviceWithoutStorage.deleteKey('id'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('generateEncryptionKey', () {
    test('produces a valid base64-encoded 256-bit (32-byte) key', () {
      final service = EncryptionService();
      final key = service.generateEncryptionKey();

      final decoded = base64.decode(key);
      expect(decoded.length, 32);
    });

    test('produces different keys on successive calls', () {
      final service = EncryptionService();
      final keys = List.generate(10, (_) => service.generateEncryptionKey());

      expect(keys.toSet().length, keys.length);
    });
  });

  group('tamper detection and wrong-key handling (AES-GCM auth tag)', () {
    late EncryptionService service;
    late Directory tempDir;

    setUp(() async {
      service = EncryptionService();
      tempDir = await Directory.systemTemp.createTemp('encryption_tamper_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('decryptFile throws when the file is decrypted with the wrong key',
        () async {
      final source = File('${tempDir.path}/source.bin');
      final encrypted = File('${tempDir.path}/encrypted.bin');
      final decrypted = File('${tempDir.path}/decrypted.bin');

      await source.writeAsBytes(
        Uint8List.fromList(List<int>.generate(64, (i) => i)),
      );

      final correctKey = service.generateEncryptionKey();
      final wrongKey = service.generateEncryptionKey();

      await service.encryptFile(source, encrypted, correctKey);

      await expectLater(
        service.decryptFile(encrypted, decrypted, wrongKey),
        throwsA(anything),
      );
    });

    test('decryptFile throws when ciphertext bytes are tampered with',
        () async {
      final source = File('${tempDir.path}/source.bin');
      final encrypted = File('${tempDir.path}/encrypted.bin');
      final decrypted = File('${tempDir.path}/decrypted.bin');

      await source.writeAsBytes(
        Uint8List.fromList(List<int>.generate(128, (i) => i % 256)),
      );

      final key = service.generateEncryptionKey();
      await service.encryptFile(source, encrypted, key);

      // Flip a byte inside the ciphertext region (after the 20-byte
      // 'eduzone-gcm-chunked' header + 12-byte IV + 4-byte length prefix),
      // which should invalidate the GCM authentication tag.
      final bytes = await encrypted.readAsBytes();
      final tamperIndex = bytes.length - 5; // near the end of the tag/ciphertext
      final tampered = Uint8List.fromList(bytes);
      tampered[tamperIndex] = tampered[tamperIndex] ^ 0xFF;
      await encrypted.writeAsBytes(tampered, flush: true);

      await expectLater(
        service.decryptFile(encrypted, decrypted, key),
        throwsA(anything),
      );
    });
  });

  group('buildIndexForExistingFile error paths', () {
    late Directory tempDir;

    setUp(() async {
      tempDir =
          await Directory.systemTemp.createTemp('encryption_index_errors');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('throws StateError for a file without the chunked header', () async {
      final notChunked = File('${tempDir.path}/not_chunked.bin');
      await notChunked.writeAsBytes(utf8.encode('not-a-eduzone-file-at-all'));

      await expectLater(
        buildIndexForExistingFile(notChunked),
        throwsA(isA<StateError>()),
      );
    });

    test('throws ArgumentError for a chunked file truncated mid-IV', () async {
      final truncated = File('${tempDir.path}/truncated.bin');
      final header = utf8.encode('eduzone-gcm-chunked');
      // Header present, but only 4 of the 12 expected IV bytes follow.
      await truncated.writeAsBytes([...header, 1, 2, 3, 4]);

      await expectLater(
        buildIndexForExistingFile(truncated),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('small buffer encrypt/decrypt (encryptBytes/decryptBytes)', () {
    // API FIX APPLIED — for context on why this group looks different from
    // an earlier draft of this test file:
    // `EncryptionService.encryptBytes()` used to generate a random IV
    // internally and return only the ciphertext (`Encrypted`, which — per
    // the `encrypt` package — has no `.iv` getter), with no way to hand
    // that IV back to the caller. `decryptBytes()` requires that same IV
    // as a parameter, so there was previously no way to correctly pair a
    // call to `encryptBytes()` with a later `decryptBytes()` call using
    // only this service's public API.
    //
    // `encryptBytes()` now returns `({Encrypted data, IV iv})` — both the
    // ciphertext AND the IV used to produce it — so the pair is usable as
    // a matched set. The tests below cover both that fixed path directly,
    // and the lower-level `buildEncrypter()` + caller-tracked-IV path
    // (used internally by `encryptFile`'s chunk logic), which was already
    // correct and is unaffected by this change.

    test('encryptBytes + decryptBytes round-trip correctly', () {
      final service = EncryptionService();
      final key = service.generateEncryptionKey();
      final payload = Uint8List.fromList(List<int>.generate(30, (i) => i));

      final result = service.encryptBytes(payload, key);
      final decrypted = service.decryptBytes(result.data, key, result.iv);

      expect(decrypted, equals(payload));
    });

    test('encryptBytes generates a fresh IV on every call', () {
      final service = EncryptionService();
      final key = service.generateEncryptionKey();
      final payload = Uint8List.fromList(List<int>.generate(30, (i) => i));

      final first = service.encryptBytes(payload, key);
      final second = service.encryptBytes(payload, key);

      expect(first.iv.bytes, isNot(equals(second.iv.bytes)));
    });

    test(
        'decryptBytes throws when the ciphertext and IV come from different '
        'encryptBytes calls (confirms the pairing must be exact, not just '
        '"any IV of the right length")', () {
      final service = EncryptionService();
      final key = service.generateEncryptionKey();
      final payload = Uint8List.fromList(List<int>.generate(30, (i) => i));

      final first = service.encryptBytes(payload, key);
      final second = service.encryptBytes(payload, key);

      expect(
        () => service.decryptBytes(first.data, key, second.iv),
        throwsA(anything),
      );
    });

    test('buildEncrypter + decryptBytes round-trip with a caller-tracked IV',
        () {
      final service = EncryptionService();
      final key = service.generateEncryptionKey();
      final payload =
          Uint8List.fromList(List<int>.generate(200, (i) => (i * 3) % 256));

      final iv = IV.fromSecureRandom(EncryptionService.ivLength);
      final encrypter = service.buildEncrypter(key);
      final encrypted = encrypter.encryptBytes(payload, iv: iv);

      final decrypted = service.decryptBytes(encrypted, key, iv);

      expect(decrypted, equals(payload));
    });

    test('decryptBytesWithEncrypter matches decryptBytes for the same input',
        () {
      final service = EncryptionService();
      final key = service.generateEncryptionKey();
      final payload = Uint8List.fromList(List<int>.generate(50, (i) => i));

      final iv = IV.fromSecureRandom(EncryptionService.ivLength);
      final encrypter = service.buildEncrypter(key);
      final encrypted = encrypter.encryptBytes(payload, iv: iv);

      final viaDecryptBytes = service.decryptBytes(encrypted, key, iv);
      final viaEncrypterOverload = service.decryptBytesWithEncrypter(
        encrypter,
        encrypted,
        iv,
      );

      expect(viaDecryptBytes, equals(viaEncrypterOverload));
    });

    test('decryptBytes throws when given the wrong key', () {
      final service = EncryptionService();
      final correctKey = service.generateEncryptionKey();
      final wrongKey = service.generateEncryptionKey();
      final payload = Uint8List.fromList(List<int>.generate(30, (i) => i));

      final result = service.encryptBytes(payload, correctKey);

      expect(
        () => service.decryptBytes(result.data, wrongKey, result.iv),
        throwsA(anything),
      );
    });
  });

  group('calculateChecksum', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('encryption_checksum');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('is deterministic for identical content', () async {
      final service = EncryptionService();
      final fileA = File('${tempDir.path}/a.bin');
      final fileB = File('${tempDir.path}/b.bin');
      final payload =
          Uint8List.fromList(List<int>.generate(1000, (i) => i % 256));

      await fileA.writeAsBytes(payload);
      await fileB.writeAsBytes(payload);

      final checksumA = await service.calculateChecksum(fileA);
      final checksumB = await service.calculateChecksum(fileB);

      expect(checksumA, checksumB);
      expect(checksumA, hasLength(64)); // SHA-256 hex string
    });

    test('differs when content differs', () async {
      final service = EncryptionService();
      final fileA = File('${tempDir.path}/a.bin');
      final fileB = File('${tempDir.path}/b.bin');

      await fileA.writeAsBytes([1, 2, 3]);
      await fileB.writeAsBytes([1, 2, 4]);

      final checksumA = await service.calculateChecksum(fileA);
      final checksumB = await service.calculateChecksum(fileB);

      expect(checksumA, isNot(equals(checksumB)));
    });
  });

  group('empty file edge case', () {
    test('encryptFile/decryptFile round-trip a zero-byte source', () async {
      final tempDir = await Directory.systemTemp.createTemp('encryption_empty');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });

      final service = EncryptionService();
      final source = File('${tempDir.path}/empty.bin');
      final encrypted = File('${tempDir.path}/empty_encrypted.bin');
      final decrypted = File('${tempDir.path}/empty_decrypted.bin');

      await source.writeAsBytes(const []);
      final key = service.generateEncryptionKey();

      await service.encryptFile(source, encrypted, key);
      await service.decryptFile(encrypted, decrypted, key);

      expect(await decrypted.readAsBytes(), isEmpty);
    });
  });
}