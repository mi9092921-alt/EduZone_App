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
}
