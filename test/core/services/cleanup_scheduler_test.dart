import 'dart:io';

import 'package:app/core/services/cleanup_scheduler.dart';
import 'package:app/core/services/encryption_service.dart';
import 'package:app/features/downloads/data/datasources/download_local_ds.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDownloadLocalDataSource extends Mock
    implements DownloadLocalDataSource {}

class MockEncryptionService extends Mock implements EncryptionService {}

void main() {
  late MockDownloadLocalDataSource localDs;
  late MockEncryptionService encryptionService;
  late Directory tempDir;

  setUpAll(() {
    registerFallbackValue('fallback-id');
  });

  setUp(() async {
    localDs = MockDownloadLocalDataSource();
    encryptionService = MockEncryptionService();
    tempDir = await Directory.systemTemp.createTemp('cleanup_scheduler_test_');

    when(() => localDs.deleteDownload(any())).thenAnswer((_) async {});
    when(() => encryptionService.deleteKey(any())).thenAnswer((_) async {});
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<File> writeFile(String name, [String contents = 'x']) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsString(contents);
    return file;
  }

  group('CleanupScheduler.runCleanup — happy path', () {
    test('deletes the encrypted file, its .tmp/.idx siblings, the key, '
        'and the DB row for every expired download', () async {
      final encryptedFile = await writeFile('lesson-1.enc');
      final tmpFile = await writeFile('lesson-1.enc.tmp');
      final idxFile = await writeFile('lesson-1.enc.idx');
      final audioFile = await writeFile('lesson-1.audio');
      final audioTmpFile = await writeFile('lesson-1.audio.tmp');
      final audioIdxFile = await writeFile('lesson-1.audio.idx');

      when(() => localDs.getExpiredDownloads()).thenAnswer(
        (_) async => [
          {
            'id': 'dl-1',
            'encrypted_path': encryptedFile.path,
            'audio_path': audioFile.path,
          },
        ],
      );

      final result = await CleanupScheduler.runCleanup(
        localDs: localDs,
        encryptionService: encryptionService,
      );

      expect(result.total, 1);
      expect(result.removed, 1);
      expect(result.keyDeletionFailures, 0);

      for (final f in [
        encryptedFile,
        tmpFile,
        idxFile,
        audioFile,
        audioTmpFile,
        audioIdxFile,
      ]) {
        expect(await f.exists(), isFalse, reason: '${f.path} should be gone');
      }

      verify(() => encryptionService.deleteKey('dl-1')).called(1);
      verify(() => localDs.deleteDownload('dl-1')).called(1);
    });

    test('processes multiple expired rows independently', () async {
      final fileA = await writeFile('a.enc');
      final fileB = await writeFile('b.enc');

      when(() => localDs.getExpiredDownloads()).thenAnswer(
        (_) async => [
          {'id': 'a', 'encrypted_path': fileA.path, 'audio_path': null},
          {'id': 'b', 'encrypted_path': fileB.path, 'audio_path': null},
        ],
      );

      final result = await CleanupScheduler.runCleanup(
        localDs: localDs,
        encryptionService: encryptionService,
      );

      expect(result.total, 2);
      expect(result.removed, 2);
      expect(await fileA.exists(), isFalse);
      expect(await fileB.exists(), isFalse);
      verify(() => encryptionService.deleteKey('a')).called(1);
      verify(() => encryptionService.deleteKey('b')).called(1);
      verify(() => localDs.deleteDownload('a')).called(1);
      verify(() => localDs.deleteDownload('b')).called(1);
    });
  });

  group('CleanupScheduler.runCleanup — ordering invariant (P6.29/P6.30)', () {
    test('deletes files, then the key, then the DB row — in that order',
        () async {
      final file = await writeFile('order.enc');

      when(() => localDs.getExpiredDownloads()).thenAnswer(
        (_) async => [
          {'id': 'order-1', 'encrypted_path': file.path, 'audio_path': null},
        ],
      );

      await CleanupScheduler.runCleanup(
        localDs: localDs,
        encryptionService: encryptionService,
      );

      // The DB row must never be removed before the key: if key deletion
      // fails, the row must survive for retry (see the next group). This
      // asserts the happy-path call order matches that contract.
      verifyInOrder([
        () => encryptionService.deleteKey('order-1'),
        () => localDs.deleteDownload('order-1'),
      ]);
    });
  });

  group('CleanupScheduler.runCleanup — key-deletion failure safety net', () {
    test(
        'does NOT delete the DB row when key deletion fails, so the item is '
        'retried on the next cleanup cycle instead of orphaning the key '
        '(P6.29/P6.30 orphan-prevention invariant)', () async {
      final file = await writeFile('fails.enc');

      when(() => localDs.getExpiredDownloads()).thenAnswer(
        (_) async => [
          {'id': 'fails-1', 'encrypted_path': file.path, 'audio_path': null},
        ],
      );
      when(() => encryptionService.deleteKey('fails-1'))
          .thenThrow(Exception('secure storage unavailable'));

      final result = await CleanupScheduler.runCleanup(
        localDs: localDs,
        encryptionService: encryptionService,
      );

      expect(result.total, 1);
      expect(result.removed, 0);
      expect(result.keyDeletionFailures, 1);
      verifyNever(() => localDs.deleteDownload('fails-1'));
      // The file itself is still deleted even though the key deletion
      // failed — only the DB row (the retry marker) survives.
      expect(await file.exists(), isFalse);
    });

    test('a key-deletion failure on one row does not block later rows',
        () async {
      final fileA = await writeFile('bad.enc');
      final fileB = await writeFile('good.enc');

      when(() => localDs.getExpiredDownloads()).thenAnswer(
        (_) async => [
          {'id': 'bad', 'encrypted_path': fileA.path, 'audio_path': null},
          {'id': 'good', 'encrypted_path': fileB.path, 'audio_path': null},
        ],
      );
      when(() => encryptionService.deleteKey('bad'))
          .thenThrow(Exception('boom'));

      final result = await CleanupScheduler.runCleanup(
        localDs: localDs,
        encryptionService: encryptionService,
      );

      expect(result.total, 2);
      expect(result.removed, 1);
      expect(result.keyDeletionFailures, 1);
      verifyNever(() => localDs.deleteDownload('bad'));
      verify(() => localDs.deleteDownload('good')).called(1);
    });
  });

  group('CleanupScheduler.runCleanup — edge cases', () {
    test('skips rows with a null or empty id without touching storage',
        () async {
      when(() => localDs.getExpiredDownloads()).thenAnswer(
        (_) async => [
          {'id': null, 'encrypted_path': '/tmp/whatever.enc'},
          {'id': '', 'encrypted_path': '/tmp/whatever2.enc'},
        ],
      );

      final result = await CleanupScheduler.runCleanup(
        localDs: localDs,
        encryptionService: encryptionService,
      );

      expect(result.total, 2);
      expect(result.removed, 2);
      verifyNever(() => encryptionService.deleteKey(any()));
      verifyNever(() => localDs.deleteDownload(any()));
    });

    test('a row whose files are already missing on disk still completes '
        'key + DB-row cleanup instead of throwing', () async {
      when(() => localDs.getExpiredDownloads()).thenAnswer(
        (_) async => [
          {
            'id': 'ghost-1',
            'encrypted_path': '${tempDir.path}/never-existed.enc',
            'audio_path': null,
          },
        ],
      );

      final result = await CleanupScheduler.runCleanup(
        localDs: localDs,
        encryptionService: encryptionService,
      );

      expect(result.total, 1);
      expect(result.removed, 1);
      verify(() => encryptionService.deleteKey('ghost-1')).called(1);
      verify(() => localDs.deleteDownload('ghost-1')).called(1);
    });

    test('a row with neither encrypted_path nor audio_path still deletes '
        'the key and DB row', () async {
      when(() => localDs.getExpiredDownloads()).thenAnswer(
        (_) async => [
          {'id': 'no-files', 'encrypted_path': null, 'audio_path': null},
        ],
      );

      final result = await CleanupScheduler.runCleanup(
        localDs: localDs,
        encryptionService: encryptionService,
      );

      expect(result.removed, 1);
      verify(() => encryptionService.deleteKey('no-files')).called(1);
      verify(() => localDs.deleteDownload('no-files')).called(1);
    });

    test('no expired rows returns a zeroed-out summary and touches nothing',
        () async {
      when(() => localDs.getExpiredDownloads()).thenAnswer((_) async => []);

      final result = await CleanupScheduler.runCleanup(
        localDs: localDs,
        encryptionService: encryptionService,
      );

      expect(result, (total: 0, removed: 0, keyDeletionFailures: 0));
      verifyNever(() => encryptionService.deleteKey(any()));
      verifyNever(() => localDs.deleteDownload(any()));
    });
  });
}
