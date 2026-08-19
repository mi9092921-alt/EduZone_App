import 'package:app/features/downloads/domain/entities/download_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round trips a session with and without expiry', () {
    final createdAt = DateTime.utc(2026);
    final updatedAt = DateTime.utc(2026, 1, 2);
    final session = DownloadSession(
      downloadId: 'd1',
      lessonId: 'l1',
      courseId: 'c1',
      contentVersion: 'v2',
      quality: '720p',
      trackType: 'muxed',
      totalBytes: 1000,
      chunkSize: 100,
      totalChunks: 10,
      completedBytes: 400,
      status: 'downloading',
      createdAt: createdAt,
      updatedAt: updatedAt,
      sourceIdentity: 'content-hash',
      entitlementId: 'ent-1',
      expiresAt: null,
      encryptionVersion: 1,
      containerVersion: 2,
    );

    final restored = DownloadSession.fromMap(session.toMap());

    expect(restored.downloadId, 'd1');
    expect(restored.contentVersion, 'v2');
    expect(restored.totalChunks, 10);
    expect(restored.completedBytes, 400);
    expect(restored.createdAt.millisecondsSinceEpoch,
        createdAt.millisecondsSinceEpoch);
    expect(restored.expiresAt, isNull);
  });
}
