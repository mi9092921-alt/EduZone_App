import 'package:app/features/downloads/domain/entities/download_chunk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round trips nullable fields and timestamps through a map', () {
    final updatedAt = DateTime.utc(2026, 1, 2, 3, 4);
    final committedAt = DateTime.utc(2026, 1, 2, 3, 5);
    final chunk = DownloadChunk(
      downloadId: 'd1',
      chunkIndex: 2,
      plaintextStart: 100,
      plaintextLength: 200,
      encryptedOffset: 16,
      encryptedLength: 216,
      state: 'committed',
      downloadedBytes: 200,
      attempts: 2,
      checksum: 'abc',
      updatedAt: updatedAt,
      lastError: null,
      committedAt: committedAt,
    );

    final restored = DownloadChunk.fromMap(chunk.toMap());

    expect(restored.downloadId, 'd1');
    expect(restored.chunkIndex, 2);
    expect(restored.updatedAt, updatedAt);
    expect(restored.committedAt, committedAt);
    expect(restored.checksum, 'abc');
    expect(restored.lastError, isNull);
  });
}
