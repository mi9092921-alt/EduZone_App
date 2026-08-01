import 'dart:io';
import 'dart:math';

import 'package:app/core/services/edz_local_proxy.dart';
import 'package:app/core/services/encryption_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('streams decrypted bytes for full and range requests', () async {
    final tmpDir = await Directory.systemTemp.createTemp('edz_proxy_test_');
    final proxy = EdzLocalProxy();
    final client = HttpClient();

    try {
      final source = File('${tmpDir.path}/plain.mp4');
      final encrypted = File('${tmpDir.path}/encrypted.mp4.enc');
      final rnd = Random(7);
      final bytes = List<int>.generate(
        1024 * 1024 + 123,
        (_) => rnd.nextInt(256),
      );
      await source.writeAsBytes(bytes, flush: true);

      final encryptionService = EncryptionService();
      final key = encryptionService.generateEncryptionKey();
      await encryptionService.encryptFile(source, encrypted, key);
      final index = await loadOrBuildIndex(encrypted);

      final uri = await proxy.start(
        encryptedFile: encrypted,
        keyBase64: key,
        index: index,
      );

      final fullRequest = await client.getUrl(uri);
      final fullResponse = await fullRequest.close();
      final fullBytes = await fullResponse
          .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk))
          .timeout(const Duration(seconds: 5));

      expect(fullResponse.statusCode, HttpStatus.ok);
      expect(fullBytes, bytes);

      final rangeRequest = await client.getUrl(uri);
      rangeRequest.headers.set(HttpHeaders.rangeHeader, 'bytes=100-199');
      final rangeResponse = await rangeRequest.close();
      final rangeBytes = await rangeResponse
          .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk))
          .timeout(const Duration(seconds: 5));

      expect(rangeResponse.statusCode, HttpStatus.partialContent);
      expect(
        rangeResponse.headers.value(HttpHeaders.contentRangeHeader),
        'bytes 100-199/${bytes.length}',
      );
      expect(rangeBytes, bytes.sublist(100, 200));
    } finally {
      client.close(force: true);
      await proxy.stop();
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
    }
  }, timeout: const Timeout(Duration(seconds: 20)));
}
