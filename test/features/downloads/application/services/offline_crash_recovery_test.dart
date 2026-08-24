import 'dart:io';

import 'package:app/features/downloads/application/services/offline_crash_recovery.dart';
import 'package:app/features/downloads/data/datasources/download_local_ds.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDownloadLocalDataSource extends Mock
    implements DownloadLocalDataSource {}

void main() {
  late MockDownloadLocalDataSource localDataSource;
  late OfflineCrashRecovery recovery;
  late Directory tempDir;

  setUp(() {
    localDataSource = MockDownloadLocalDataSource();
    recovery = OfflineCrashRecovery(localDataSource: localDataSource);
    tempDir = Directory.systemTemp.createTempSync('offline_crash_recovery_test');

    when(() => localDataSource.updateDownloadStatus(any(), any()))
        .thenAnswer((_) async {});
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('reclassifies a stuck "downloading" row to failed', () async {
    when(() => localDataSource.getDownloads(scopeToCurrentUser: false))
        .thenAnswer(
      (_) async => [
        {
          'id': 'dl_stuck',
          'download_status': 'downloading',
          'encrypted_path': null,
          'audio_path': null,
        },
      ],
    );

    final count = await recovery.reconcileInterruptedDownloads();

    expect(count, equals(1));
    verify(() => localDataSource.updateDownloadStatus('dl_stuck', 'failed'))
        .called(1);
  });

  test('reclassifies a stuck "pending" row to failed', () async {
    when(() => localDataSource.getDownloads(scopeToCurrentUser: false))
        .thenAnswer(
      (_) async => [
        {
          'id': 'dl_pending',
          'download_status': 'pending',
          'encrypted_path': null,
          'audio_path': null,
        },
      ],
    );

    final count = await recovery.reconcileInterruptedDownloads();

    expect(count, equals(1));
    verify(() => localDataSource.updateDownloadStatus('dl_pending', 'failed'))
        .called(1);
  });

  test('never touches completed, failed, or paused rows', () async {
    when(() => localDataSource.getDownloads(scopeToCurrentUser: false))
        .thenAnswer(
      (_) async => [
        {'id': 'dl_completed', 'download_status': 'completed'},
        {'id': 'dl_failed', 'download_status': 'failed'},
        {'id': 'dl_paused', 'download_status': 'paused'},
      ],
    );

    final count = await recovery.reconcileInterruptedDownloads();

    expect(count, equals(0));
    verifyNever(() => localDataSource.updateDownloadStatus(any(), any()));
  });

  test('deletes .tmp and .idx partial artifacts for reconciled rows',
      () async {
    final basePath = '${tempDir.path}/lesson.enc';
    File('$basePath.tmp').writeAsBytesSync([1]);
    File('$basePath.idx').writeAsBytesSync([1]);

    when(() => localDataSource.getDownloads(scopeToCurrentUser: false))
        .thenAnswer(
      (_) async => [
        {
          'id': 'dl_stuck',
          'download_status': 'downloading',
          'encrypted_path': basePath,
          'audio_path': null,
        },
      ],
    );

    await recovery.reconcileInterruptedDownloads();

    expect(File('$basePath.tmp').existsSync(), isFalse);
    expect(File('$basePath.idx').existsSync(), isFalse);
  });

  test('a row that fails to update is not counted as reconciled', () async {
    when(() => localDataSource.getDownloads(scopeToCurrentUser: false))
        .thenAnswer(
      (_) async => [
        {
          'id': 'dl_stuck',
          'download_status': 'downloading',
          'encrypted_path': null,
          'audio_path': null,
        },
      ],
    );
    when(() => localDataSource.updateDownloadStatus('dl_stuck', 'failed'))
        .thenThrow(Exception('db locked'));

    final count = await recovery.reconcileInterruptedDownloads();

    expect(count, equals(0));
  });

  group('reconcileOrphanedDownloadFiles', () {
    setUp(() {
      when(() => localDataSource.getDownloadsDirectory())
          .thenAnswer((_) async => tempDir);
    });

    test('deletes a file with no matching database row', () async {
      final orphan = File('${tempDir.path}/orphan.enc')
        ..writeAsBytesSync([1]);
      when(() => localDataSource.getDownloads(scopeToCurrentUser: false))
          .thenAnswer((_) async => []);

      final count = await recovery.reconcileOrphanedDownloadFiles();

      expect(count, equals(1));
      expect(orphan.existsSync(), isFalse);
    });

    test('preserves a file matching a row\'s encrypted_path or audio_path',
        () async {
      final videoPath = '${tempDir.path}/lesson.mp4.enc';
      final audioPath = '${tempDir.path}/lesson_audio.m4a.enc';
      File(videoPath).writeAsBytesSync([1]);
      File(audioPath).writeAsBytesSync([1]);
      when(() => localDataSource.getDownloads(scopeToCurrentUser: false))
          .thenAnswer(
        (_) async => [
          {
            'id': 'dl_claimed',
            'download_status': 'completed',
            'encrypted_path': videoPath,
            'audio_path': audioPath,
          },
        ],
      );

      final count = await recovery.reconcileOrphanedDownloadFiles();

      expect(count, equals(0));
      expect(File(videoPath).existsSync(), isTrue);
      expect(File(audioPath).existsSync(), isTrue);
    });

    test('preserves .tmp/.idx sidecars of a row that still exists, '
        'regardless of status', () async {
      final basePath = '${tempDir.path}/lesson.mp4.enc';
      File(basePath).writeAsBytesSync([1]);
      File('$basePath.tmp').writeAsBytesSync([1]);
      File('$basePath.idx').writeAsBytesSync([1]);
      when(() => localDataSource.getDownloads(scopeToCurrentUser: false))
          .thenAnswer(
        (_) async => [
          {
            'id': 'dl_paused',
            'download_status': 'paused',
            'encrypted_path': basePath,
            'audio_path': null,
          },
        ],
      );

      final count = await recovery.reconcileOrphanedDownloadFiles();

      expect(count, equals(0));
      expect(File('$basePath.tmp').existsSync(), isTrue);
      expect(File('$basePath.idx').existsSync(), isTrue);
    });

    test('mixed directory: deletes only the unclaimed file', () async {
      final claimedPath = '${tempDir.path}/claimed.enc';
      final orphanPath = '${tempDir.path}/orphan.enc';
      File(claimedPath).writeAsBytesSync([1]);
      File(orphanPath).writeAsBytesSync([1]);
      when(() => localDataSource.getDownloads(scopeToCurrentUser: false))
          .thenAnswer(
        (_) async => [
          {
            'id': 'dl_claimed',
            'download_status': 'completed',
            'encrypted_path': claimedPath,
            'audio_path': null,
          },
        ],
      );

      final count = await recovery.reconcileOrphanedDownloadFiles();

      expect(count, equals(1));
      expect(File(claimedPath).existsSync(), isTrue);
      expect(File(orphanPath).existsSync(), isFalse);
    });

    test('returns 0 when the downloads directory does not exist', () async {
      final missingDir =
          Directory('${tempDir.path}/does_not_exist_${DateTime.now().microsecondsSinceEpoch}');
      when(() => localDataSource.getDownloadsDirectory())
          .thenAnswer((_) async => missingDir);

      final count = await recovery.reconcileOrphanedDownloadFiles();

      expect(count, equals(0));
    });
  });

  group('reconcileMissingCompletedFiles', () {
    test('leaves a completed row alone when its file still exists',
        () async {
      final videoPath = '${tempDir.path}/present.mp4.enc';
      File(videoPath).writeAsBytesSync([1]);
      when(() => localDataSource.getDownloads(scopeToCurrentUser: false))
          .thenAnswer(
        (_) async => [
          {
            'id': 'dl_present',
            'download_status': 'completed',
            'encrypted_path': videoPath,
            'audio_path': null,
          },
        ],
      );

      final count = await recovery.reconcileMissingCompletedFiles();

      expect(count, equals(0));
      verifyNever(() => localDataSource.updateDownloadStatus(any(), any()));
    });

    test('reclassifies a completed row to failed when its file is gone',
        () async {
      final videoPath = '${tempDir.path}/gone.mp4.enc';
      // Deliberately never created — simulates external deletion of a
      // file whose row was never told about it.
      when(() => localDataSource.getDownloads(scopeToCurrentUser: false))
          .thenAnswer(
        (_) async => [
          {
            'id': 'dl_gone',
            'download_status': 'completed',
            'encrypted_path': videoPath,
            'audio_path': null,
          },
        ],
      );

      final count = await recovery.reconcileMissingCompletedFiles();

      expect(count, equals(1));
      verify(() => localDataSource.updateDownloadStatus('dl_gone', 'failed'))
          .called(1);
    });

    test('reclassifies a dual-track completed row when only the audio '
        'file is missing', () async {
      final videoPath = '${tempDir.path}/dual_video.mp4.enc';
      final audioPath = '${tempDir.path}/dual_audio.m4a.enc';
      File(videoPath).writeAsBytesSync([1]);
      // audioPath deliberately never created.
      when(() => localDataSource.getDownloads(scopeToCurrentUser: false))
          .thenAnswer(
        (_) async => [
          {
            'id': 'dl_dual',
            'download_status': 'completed',
            'encrypted_path': videoPath,
            'audio_path': audioPath,
          },
        ],
      );

      final count = await recovery.reconcileMissingCompletedFiles();

      expect(count, equals(1));
      verify(() => localDataSource.updateDownloadStatus('dl_dual', 'failed'))
          .called(1);
    });

    test('never touches pending, downloading, paused, or already-failed '
        'rows regardless of whether their file exists', () async {
      when(() => localDataSource.getDownloads(scopeToCurrentUser: false))
          .thenAnswer(
        (_) async => [
          {
            'id': 'dl_pending',
            'download_status': 'pending',
            'encrypted_path': '${tempDir.path}/does_not_exist_pending.enc',
            'audio_path': null,
          },
          {
            'id': 'dl_downloading',
            'download_status': 'downloading',
            'encrypted_path':
                '${tempDir.path}/does_not_exist_downloading.enc',
            'audio_path': null,
          },
          {
            'id': 'dl_paused',
            'download_status': 'paused',
            'encrypted_path': '${tempDir.path}/does_not_exist_paused.enc',
            'audio_path': null,
          },
          {
            'id': 'dl_failed',
            'download_status': 'failed',
            'encrypted_path': '${tempDir.path}/does_not_exist_failed.enc',
            'audio_path': null,
          },
        ],
      );

      final count = await recovery.reconcileMissingCompletedFiles();

      expect(count, equals(0));
      verifyNever(() => localDataSource.updateDownloadStatus(any(), any()));
    });

    test('treats a null/empty encrypted_path on a completed row as missing',
        () async {
      when(() => localDataSource.getDownloads(scopeToCurrentUser: false))
          .thenAnswer(
        (_) async => [
          {
            'id': 'dl_null_path',
            'download_status': 'completed',
            'encrypted_path': null,
            'audio_path': null,
          },
        ],
      );

      final count = await recovery.reconcileMissingCompletedFiles();

      expect(count, equals(1));
      verify(() =>
              localDataSource.updateDownloadStatus('dl_null_path', 'failed'))
          .called(1);
    });
  });
}
