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

  setUp(() {
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
  });

  test('prepares a decrypted temp file and cleans it up', () async {
    const tempDirName = 'offline_playback_service_test';
    final tempDir = await Directory.systemTemp.createTemp(tempDirName);
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    const downloadId = 'download-1';
    final sourceFile = File('${tempDir.path}/source.mp4');
    final encryptedFile = File('${tempDir.path}/encrypted.mp4');
    final originalPayload = Uint8List.fromList(List<int>.generate(64, (index) => index));
    await sourceFile.writeAsBytes(originalPayload);

    final key = encryptionService.generateEncryptionKey();
    await encryptionService.storeKey(downloadId, key);
    await encryptionService.encryptFile(sourceFile, encryptedFile, key);

    final preparedFile = await service.preparePlayableFile(
      downloadId: downloadId,
      encryptedPath: encryptedFile.path,
      outputPath: '${tempDir.path}/prepared.mp4',
    );

    expect(await preparedFile.readAsBytes(), equals(originalPayload));

    await service.cleanupTempFile(preparedFile);
    expect(await preparedFile.exists(), isFalse);
  });
}
