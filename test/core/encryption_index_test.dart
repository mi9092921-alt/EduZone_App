import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:app/core/services/encryption_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildIndexForExistingFile matches sidecar index from encryptFile', () async {
    final tmpDir = await Directory.systemTemp.createTemp('edz_test_');
    try {
      final source = File('${tmpDir.path}/plain.bin');
      final dest = File('${tmpDir.path}/encrypted.edz');

      // Generate deterministic content large enough for multiple chunks
      final rnd = Random(42);
      const size = 1024 * 1024; // 1 MiB - ensures multiple 512KiB chunks
      final bytes = List<int>.generate(size, (_) => rnd.nextInt(256));
      await source.writeAsBytes(bytes, flush: true);

      final service = EncryptionService(); // no secure storage required for encryptFile
      final key = service.generateEncryptionKey();

      await service.encryptFile(source, dest, key);

      // Load index from sidecar written by encryptFile
      final sidecarIndex = await loadOrBuildIndex(dest);

      // Rebuild index by scanning file
      final scannedIndex = await buildIndexForExistingFile(dest);

      expect(sidecarIndex.totalPlaintextSize, scannedIndex.totalPlaintextSize);
      expect(sidecarIndex.chunks.length, scannedIndex.chunks.length);

      for (var i = 0; i < sidecarIndex.chunks.length; i++) {
        final a = sidecarIndex.chunks[i];
        final b = scannedIndex.chunks[i];
        expect(a.encryptedOffset, b.encryptedOffset);
        expect(a.encryptedLength, b.encryptedLength);
        expect(a.plaintextLength, b.plaintextLength);
        // Ensure encryptedLength accounts for GCM tag
        expect(a.encryptedLength, a.plaintextLength + EncryptionService.gcmTagLength);
      }

      // Also verify that decrypting the file yields the original plaintext
      final decrypted = File('${tmpDir.path}/decrypted.bin');
      await service.decryptFile(dest, decrypted, key);
      final decBytes = await decrypted.readAsBytes();
      expect(decBytes.length, bytes.length);
      expect(decBytes, bytes);
    } finally {
      await tmpDir.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('rebuilds a malformed sidecar without changing the encrypted file', () async {
    final tmpDir = await Directory.systemTemp.createTemp('edz_index_recovery_test_');
    try {
      final source = File('${tmpDir.path}/plain.bin');
      final dest = File('${tmpDir.path}/encrypted.edz');
      await source.writeAsBytes(List<int>.generate(1024, (index) => index % 251));

      final service = EncryptionService();
      await service.encryptFile(source, dest, service.generateEncryptionKey());
      final encryptedBytesBefore = await dest.readAsBytes();

      final idxFile = File('${dest.path}.idx');
      await idxFile.writeAsString('{not valid json');

      final rebuilt = await loadOrBuildIndex(dest);

      expect(rebuilt.version, 1);
      expect(rebuilt.totalPlaintextSize, 1024);
      expect(await dest.readAsBytes(), equals(encryptedBytesBefore));
      final persisted = json.decode(await idxFile.readAsString()) as Map<String, dynamic>;
      expect(persisted['totalPlaintextSize'], 1024);
    } finally {
      if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('rebuilds a stale sidecar whose offsets no longer match the file', () async {
    final tmpDir = await Directory.systemTemp.createTemp('edz_index_stale_test_');
    try {
      final source = File('${tmpDir.path}/plain.bin');
      final dest = File('${tmpDir.path}/encrypted.edz');
      await source.writeAsBytes(List<int>.generate(1024, (index) => index % 251));

      final service = EncryptionService();
      await service.encryptFile(source, dest, service.generateEncryptionKey());
      final idxFile = File('${dest.path}.idx');
      final original = json.decode(await idxFile.readAsString()) as Map<String, dynamic>;
      final chunks = (original['chunks'] as List)
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();
      chunks.first['encryptedOffset'] = (chunks.first['encryptedOffset'] as int) + 1;
      await idxFile.writeAsString(json.encode({...original, 'chunks': chunks}));

      final rebuilt = await loadOrBuildIndex(dest);

      expect(rebuilt.chunks.first.encryptedOffset, chunkedFormatHeaderBytes.length);
    } finally {
      if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(seconds: 60)));
}
