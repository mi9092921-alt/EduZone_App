import '../../../../core/services/encryption_service.dart';
import '../../domain/entities/download_chunk.dart';
import '../../domain/entities/download_session.dart';
import '../datasources/download_local_ds.dart';

/// Persists the deterministic encryption plan before network work starts.
///
/// This service is deliberately unaware of Dio, background execution, and
/// UI state. It only turns the existing [PlannedChunk] layout into durable
/// session/chunk records. Existing chunk rows are preserved so a later resume
/// cannot accidentally downgrade a verified chunk to pending.
class DownloadManifestService {
  DownloadManifestService({required DownloadLocalDataSource localDataSource})
      : _localDataSource = localDataSource;

  final DownloadLocalDataSource _localDataSource;

  Future<void> persistPlan({
    required DownloadSession session,
    required List<PlannedChunk> plan,
  }) async {
    if (plan.length != session.totalChunks) {
      throw ArgumentError.value(
        plan.length,
        'plan',
        'must contain exactly session.totalChunks entries',
      );
    }

    await _localDataSource.saveDownloadSession(session);
    final existing = await _localDataSource.getDownloadChunks(session.downloadId);
    final existingIndexes = existing.map((chunk) => chunk.chunkIndex).toSet();
    final now = DateTime.now();

    for (final planned in plan) {
      if (existingIndexes.contains(planned.index)) continue;
      await _localDataSource.saveDownloadChunk(
        DownloadChunk(
          downloadId: session.downloadId,
          chunkIndex: planned.index,
          plaintextStart: planned.plaintextStart,
          plaintextLength: planned.plaintextLength,
          encryptedOffset: planned.encryptedOffset,
          encryptedLength: planned.recordLength,
          state: 'pending',
          downloadedBytes: 0,
          attempts: 0,
          checksum: null,
          updatedAt: now,
          lastError: null,
          committedAt: null,
        ),
      );
    }
  }

  Future<void> commitChunk({
    required String downloadId,
    required PlannedChunk chunk,
    String? checksum,
  }) async {
    await _localDataSource.commitDownloadChunk(
      downloadId: downloadId,
      chunkIndex: chunk.index,
      completedBytes: chunk.plaintextLength,
      checksum: checksum,
    );
  }

  Future<Set<int>> getVerifiedChunkIndexes(String downloadId) async {
    final chunks = await _localDataSource.getDownloadChunks(downloadId);
    return chunks
        .where((chunk) => chunk.state == 'verified')
        .map((chunk) => chunk.chunkIndex)
        .toSet();
  }

  Future<void> markPaused(String downloadId) async {
    final chunks = await _localDataSource.getDownloadChunks(downloadId);
    for (final chunk in chunks) {
      if (chunk.state != 'fetching' &&
          chunk.state != 'encrypting' &&
          chunk.state != 'persisted') {
        continue;
      }
      await _localDataSource.updateDownloadChunk(
        downloadId,
        chunk.chunkIndex,
        {
          'state': 'pending',
          'downloaded_bytes': 0,
          'last_error': 'Paused before chunk commit',
        },
      );
    }
    await _localDataSource.updateDownloadSession(
      downloadId,
      {'status': 'paused'},
    );
  }

  Future<void> markRunning(String downloadId) async {
    await _localDataSource.updateDownloadSession(
      downloadId,
      {'status': 'downloading'},
    );
  }
}
