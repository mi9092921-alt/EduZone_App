import 'package:app/core/services/encryption_service.dart';
import 'package:app/features/downloads/data/datasources/download_local_ds.dart';
import 'package:app/features/downloads/data/services/download_manifest_service.dart';
import 'package:app/features/downloads/domain/entities/download_chunk.dart';
import 'package:app/features/downloads/domain/entities/download_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDownloadLocalDataSource extends Mock
    implements DownloadLocalDataSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(DownloadSession(
      downloadId: 'fallback',
      lessonId: 'fallback',
      courseId: 'fallback',
      contentVersion: 'fallback',
      quality: '720p',
      trackType: 'video',
      totalBytes: 0,
      chunkSize: 0,
      totalChunks: 0,
      completedBytes: 0,
      status: 'pending',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      sourceIdentity: 'fallback',
      entitlementId: 'fallback',
      expiresAt: null,
      encryptionVersion: 1,
      containerVersion: 1,
    ));
    registerFallbackValue(DownloadChunk(
      downloadId: 'fallback',
      chunkIndex: 0,
      plaintextStart: 0,
      plaintextLength: 0,
      encryptedOffset: 0,
      encryptedLength: 0,
      state: 'pending',
      downloadedBytes: 0,
      attempts: 0,
      checksum: null,
      updatedAt: DateTime(2026),
      lastError: null,
      committedAt: null,
    ));
  });

  late MockDownloadLocalDataSource localDataSource;
  late DownloadManifestService service;

  final createdAt = DateTime(2026);
  final session = DownloadSession(
    downloadId: 'download-1',
    lessonId: 'lesson-1',
    courseId: 'course-1',
    contentVersion: 'v1',
    quality: '720p',
    trackType: 'video',
    totalBytes: 1024,
    chunkSize: kEncryptionChunkSize,
    totalChunks: 2,
    completedBytes: 0,
    status: 'downloading',
    createdAt: createdAt,
    updatedAt: createdAt,
    sourceIdentity: 'lesson-1:v1:720p:video',
    entitlementId: 'entitlement-1',
    expiresAt: null,
    encryptionVersion: 1,
    containerVersion: 1,
  );

  setUp(() {
    localDataSource = MockDownloadLocalDataSource();
    service = DownloadManifestService(localDataSource: localDataSource);
    when(() => localDataSource.saveDownloadSession(any()))
        .thenAnswer((_) async {});
    when(() => localDataSource.getDownloadChunks('download-1'))
        .thenAnswer((_) async => const <DownloadChunk>[]);
    when(() => localDataSource.getDownloadSession('download-1'))
        .thenAnswer((_) async => null);
    when(() => localDataSource.saveDownloadChunk(any()))
        .thenAnswer((_) async {});
  });

  test('persists one pending manifest row per planned chunk', () async {
    final plan = planChunkLayout(1024, chunkSize: 512);

    await service.persistPlan(session: session, plan: plan);

    final saved = verify(
      () => localDataSource.saveDownloadSession(captureAny()),
    ).captured.single as DownloadSession;
    expect(saved.downloadId, session.downloadId);
    expect(saved.completedBytes, 0);
    final captured = verify(
      () => localDataSource.saveDownloadChunk(captureAny()),
    ).captured.cast<DownloadChunk>();
    expect(captured, hasLength(2));
    expect(captured.every((chunk) => chunk.state == 'pending'), isTrue);
    expect(captured.map((chunk) => chunk.chunkIndex), orderedEquals([0, 1]));
  });

  test('preserves existing chunks when a plan is persisted again', () async {
    when(() => localDataSource.getDownloadChunks('download-1')).thenAnswer(
      (_) async => [
        DownloadChunk(
          downloadId: 'download-1',
          chunkIndex: 0,
          plaintextStart: 0,
          plaintextLength: 512,
          encryptedOffset: chunkedFormatHeaderBytes.length,
          encryptedLength: 512 + 16 + 12 + 4,
          state: 'verified',
          downloadedBytes: 512,
          attempts: 1,
          checksum: 'checksum',
          updatedAt: createdAt,
          lastError: null,
          committedAt: createdAt,
        ),
      ],
    );

    await service.persistPlan(
      session: session,
      plan: planChunkLayout(1024, chunkSize: 512),
    );

    final captured = verify(
      () => localDataSource.saveDownloadChunk(captureAny()),
    ).captured.cast<DownloadChunk>();
    expect(captured, hasLength(1));
    expect(captured.single.chunkIndex, 1);
  });

  test('preserves completed bytes and creation time when resuming a plan',
      () async {
    final persistedAt = DateTime(2025);
    when(() => localDataSource.getDownloadSession('download-1'))
        .thenAnswer((_) async => session.copyWithProgressForTest(
              completedBytes: 512,
              createdAt: persistedAt,
            ));
    when(() => localDataSource.getDownloadChunks('download-1')).thenAnswer(
      (_) async => [
        DownloadChunk(
          downloadId: 'download-1',
          chunkIndex: 0,
          plaintextStart: 0,
          plaintextLength: 512,
          encryptedOffset: chunkedFormatHeaderBytes.length,
          encryptedLength: 512 + 16 + 12 + 4,
          state: 'verified',
          downloadedBytes: 512,
          attempts: 1,
          checksum: 'checksum',
          updatedAt: persistedAt,
          lastError: null,
          committedAt: persistedAt,
        ),
      ],
    );

    await service.persistPlan(
      session: session,
      plan: planChunkLayout(1024, chunkSize: 512),
    );

    final saved = verify(
      () => localDataSource.saveDownloadSession(captureAny()),
    ).captured.single as DownloadSession;
    expect(saved.completedBytes, 512);
    expect(saved.createdAt, persistedAt);
  });

  test('pauses all possible track manifests for a dual-track download',
      () async {
    when(() => localDataSource.getDownloadChunks(any()))
        .thenAnswer((_) async => const <DownloadChunk>[]);
    when(() => localDataSource.updateDownloadSession(any(), any()))
        .thenAnswer((_) async {});

    await service.markPaused('download-1');

    verify(() => localDataSource.updateDownloadSession(
          'download-1_video',
          {'status': 'paused'},
        )).called(1);
    verify(() => localDataSource.updateDownloadSession(
          'download-1_audio',
          {'status': 'paused'},
        )).called(1);
  });
}

extension on DownloadSession {
  DownloadSession copyWithProgressForTest({
    required int completedBytes,
    required DateTime createdAt,
  }) {
    return DownloadSession(
      downloadId: downloadId,
      lessonId: lessonId,
      courseId: courseId,
      contentVersion: contentVersion,
      quality: quality,
      trackType: trackType,
      totalBytes: totalBytes,
      chunkSize: chunkSize,
      totalChunks: totalChunks,
      completedBytes: completedBytes,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      sourceIdentity: sourceIdentity,
      entitlementId: entitlementId,
      expiresAt: expiresAt,
      encryptionVersion: encryptionVersion,
      containerVersion: containerVersion,
    );
  }
}
