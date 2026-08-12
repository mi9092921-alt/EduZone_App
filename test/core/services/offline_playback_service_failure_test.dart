// Failure-path coverage for OfflinePlaybackService that isn't in
// test/core/services/offline_playback_service_test.dart, which only
// covers the happy path.
//
// Copy to: test/core/services/offline_playback_service_failure_test.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:app/core/services/encryption_service.dart';
import 'package:app/core/services/offline_playback_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OfflinePlaybackService service;
  late EncryptionService encryptionService;
  late MockFlutterSecureStorage storage;
  late Map<String, String> storedValues;
  late Directory tempDir;

  setUp(() async {
    storage = MockFlutterSecureStorage();
    storedValues = <String, String>{};
    encryptionService = EncryptionService(storage);
    service = OfflinePlaybackService(encryptionService: encryptionService);

    when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((invocation) async {
      final key = invocation.namedArguments[#key] as String;
      final value = invocation.namedArguments[#value] as String;
      storedValues[key] = value;
    });

    when(() => storage.read(key: any(named: 'key'))).thenAnswer((invocation) async {
      final key = invocation.namedArguments[#key] as String;
      return storedValues[key];
    });

    tempDir = await Directory.systemTemp.createTemp('offline_playback_failure_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('preparePlayableFile throws StateError when no key was ever stored',
      () async {
    // Note: no storage.write() happened for this downloadId, so
    // storage.read() (stubbed above) returns null — matching a real
    // "key not found" scenario, not just a raw mock miss.
    final encryptedFile = File('${tempDir.path}/encrypted.mp4');
    await encryptedFile.writeAsBytes([1, 2, 3]);

    await expectLater(
      service.preparePlayableFile(
        downloadId: 'never-stored-download',
        encryptedPath: encryptedFile.path,
        outputPath: '${tempDir.path}/out.mp4',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('preparePlayableFile deletes the partial output file if decryption fails',
      () async {
    const downloadId = 'download-corrupt';
    final key = encryptionService.generateEncryptionKey();
    await encryptionService.storeKey(downloadId, key);

    // Write a file that has a valid chunked header but garbage/truncated
    // payload afterwards, so decryptFile fails partway through and the
    // sink will have already created (and partially written) the output.
    final corruptEncrypted = File('${tempDir.path}/corrupt.mp4');
    await corruptEncrypted.writeAsBytes(
      Uint8List.fromList([
        ...'eduzone-gcm-chunked'.codeUnits,
        ...List<int>.filled(8, 0), // truncated IV — too short to be valid
      ]),
    );

    final outputPath = '${tempDir.path}/prepared_corrupt.mp4';

    await expectLater(
      service.preparePlayableFile(
        downloadId: downloadId,
        encryptedPath: corruptEncrypted.path,
        outputPath: outputPath,
      ),
      throwsA(anything),
    );

    // The service must not leave a partial/plaintext artifact behind.
    expect(await File(outputPath).exists(), isFalse);
  });

  test('startStreamingProxy throws StateError when no key was ever stored',
      () async {
    final encryptedFile = File('${tempDir.path}/encrypted.edz');
    await encryptedFile.writeAsBytes(
      Uint8List.fromList('eduzone-gcm-chunked'.codeUnits),
    );

    await expectLater(
      service.startStreamingProxy(
        downloadId: 'never-stored-download',
        encryptedPath: encryptedFile.path,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('cleanupTempFile is a no-op (does not throw) when the file does not exist',
      () async {
    final missing = File('${tempDir.path}/does_not_exist.mp4');
    expect(await missing.exists(), isFalse);

    // Should complete without throwing.
    await service.cleanupTempFile(missing);
  });
}