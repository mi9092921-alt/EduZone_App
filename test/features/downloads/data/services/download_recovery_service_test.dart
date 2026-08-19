import 'dart:io';

import 'package:app/features/downloads/data/datasources/download_local_ds.dart';
import 'package:app/features/downloads/data/services/download_recovery_service.dart';
import 'package:app/features/downloads/domain/entities/download_chunk.dart';
import 'package:app/features/downloads/domain/entities/download_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDownloadLocalDataSource extends Mock
    implements DownloadLocalDataSource {}

void main() {
  late MockDownloadLocalDataSource localDataSource;
  late DownloadRecoveryService service;
  late Directory tempDir;

  final session = DownloadSession(
    downloadId: 'download-1',
    lessonId: 'lesson-1',
    courseId: 'course-1',
    contentVersion: 'v1',
    quality: '720p',
    trackType: 'video',
    totalBytes: 512,
    chunkSize: 512,
    totalChunks: 1,
    completedBytes: 512,
    status: 'downloading',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    sourceIdentity: 'lesson-1:v1:720p:video',
    entitlementId: 'entitlement-1',
    expiresAt: null,
    encryptionVersion: 1,
    containerVersion: 1,
  );

  setUp(() async {
    localDataSource = MockDownloadLocalDataSource();
    service = DownloadRecoveryService(localDataSource: localDataSource);
    tempDir = await Directory.systemTemp.createTemp('download_recovery_test');
    when(() => localDataSource.getDownloadSessions())
        .thenAnswer((_) async => [session]);
    when(() => localDataSource.getDownloadChunks('download-1'))
        .thenAnswer((_) async => [
              DownloadChunk(
                downloadId: 'download-1',
                chunkIndex: 0,
                plaintextStart: 0,
                plaintextLength: 512,
                encryptedOffset: 18,
                encryptedLength: 532,
                state: 'fetching',
                downloadedBytes: 100,
                attempts: 1,
                checksum: null,
                updatedAt: DateTime(2026),
                lastError: 'interrupted',
                committedAt: null,
              ),
            ]);
    when(() => localDataSource.getDownloadById(
          'download-1',
          scopeToCurrentUser: false,
        ))
        .thenAnswer((_) async => {
              'encrypted_path': '${tempDir.path}${Platform.pathSeparator}video.enc',
              'audio_path': null,
            });
    when(() => localDataSource.updateDownloadChunk(any(), any(), any()))
        .thenAnswer((_) async {});
    when(() => localDataSource.updateDownloadSession(any(), any()))
        .thenAnswer((_) async {});
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('resets interrupted chunks and active session to pending', () async {
    final report = await service.reconcile();

    expect(report.sessionsScanned, 1);
    expect(report.chunksReset, 1);
    expect(report.chunksInvalidated, 0);
    verify(() => localDataSource.updateDownloadChunk(
          'download-1',
          0,
          any(),
        )).called(1);
    verify(() => localDataSource.updateDownloadSession(
          'download-1',
          {'status': 'pending'},
        )).called(1);
  });
}
