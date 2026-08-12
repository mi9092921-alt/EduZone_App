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

  late EncryptionService service;
  late MockFlutterSecureStorage storage;

  setUp(() {
    storage = MockFlutterSecureStorage();
    service = EncryptionService(storage);
  });

  test('encryptFile and decryptFile preserve small data', () async {
    final tempDir = await Directory.systemTemp.createTemp('encryption_service_test');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final sourceFile = File('${tempDir.path}/source.bin');
    final encryptedFile = File('${tempDir.path}/encrypted.bin');
    final decryptedFile = File('${tempDir.path}/decrypted.bin');

    final originalPayload = Uint8List.fromList(
      List<int>.generate(48, (index) => (index * 7) % 256),
    );
    await sourceFile.writeAsBytes(originalPayload);

    final key = service.generateEncryptionKey();

    await service.encryptFile(sourceFile, encryptedFile, key);
    await service.decryptFile(encryptedFile, decryptedFile, key);

    expect(await decryptedFile.readAsBytes(), equals(originalPayload));
  });

  test('encryptFile and decryptFile preserve large multi-chunk data (> 256KB)', () async {
    final tempDir = await Directory.systemTemp.createTemp('encryption_service_large_test');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final sourceFile = File('${tempDir.path}/source.bin');
    final encryptedFile = File('${tempDir.path}/encrypted.bin');
    final decryptedFile = File('${tempDir.path}/decrypted.bin');

    // Create a 300 KB file (larger than 256 KB chunk size)
    final originalPayload = Uint8List.fromList(
      List<int>.generate(300 * 1024, (index) => index % 256),
    );
    await sourceFile.writeAsBytes(originalPayload);

    final key = service.generateEncryptionKey();

    await service.encryptFile(sourceFile, encryptedFile, key);
    await service.decryptFile(encryptedFile, decryptedFile, key);

    expect(await decryptedFile.readAsBytes(), equals(originalPayload));
  });

  test('decryptFile correctly decrypts old single-payload format (backward compatibility)', () async {
    final tempDir = await Directory.systemTemp.createTemp('encryption_legacy_test');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final sourceFile = File('${tempDir.path}/legacy_source.bin');
    final encryptedFile = File('${tempDir.path}/legacy_encrypted.bin');
    final decryptedFile = File('${tempDir.path}/legacy_decrypted.bin');

    final originalPayload = Uint8List.fromList(
      List<int>.generate(100, (index) => index),
    );
    await sourceFile.writeAsBytes(originalPayload);

    final keyBase64 = service.generateEncryptionKey();
    
    // Encrypt using the old format logic:
    final key = Key.fromBase64(keyBase64);
    final iv = IV.fromSecureRandom(12);
    final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
    final encrypted = encrypter.encryptBytes(originalPayload, iv: iv);
    final payloadToWrite = Uint8List.fromList(
      utf8.encode('eduzone-gcm') + iv.bytes + encrypted.bytes,
    );
    await encryptedFile.writeAsBytes(payloadToWrite);

    // Decrypt using the new service method:
    await service.decryptFile(encryptedFile, decryptedFile, keyBase64);

    expect(await decryptedFile.readAsBytes(), equals(originalPayload));
  });
}
