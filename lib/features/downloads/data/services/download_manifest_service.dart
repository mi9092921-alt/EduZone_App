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

    final existing = await _localDataSource.getDownloadChunks(session.downloadId);
    final existingSession =
        await _localDataSource.getDownloadSession(session.downloadId);
    final verifiedBytes = existing
        .where((chunk) => chunk.state == 'verified')
        .fold<int>(0, (sum, chunk) => sum + chunk.plaintextLength);
    final preservedCompletedBytes = existingSession == null
        ? verifiedBytes
        : (existingSession.completedBytes > verifiedBytes
              ? existingSession.completedBytes
              : verifiedBytes);
    await _localDataSource.saveDownloadSession(
      session.copyWithProgress(
        completedBytes: preservedCompletedBytes,
        createdAt: existingSession?.createdAt ?? session.createdAt,
      ),
    );
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
    for (final trackId in _trackIds(downloadId)) {
      final chunks = await _localDataSource.getDownloadChunks(trackId);
      for (final chunk in chunks) {
        if (chunk.state != 'fetching' &&
            chunk.state != 'encrypting' &&
            chunk.state != 'persisted') {
          continue;
        }
        await _localDataSource.updateDownloadChunk(
          trackId,
          chunk.chunkIndex,
          {
            'state': 'pending',
            'downloaded_bytes': 0,
            'last_error': 'Paused before chunk commit',
          },
        );
      }
      await _localDataSource.updateDownloadSession(trackId, {'status': 'paused'});
    }
  }

  Future<void> markRunning(String downloadId) async {
    for (final trackId in _trackIds(downloadId)) {
      await _localDataSource.updateDownloadSession(
        trackId,
        {'status': 'downloading'},
      );
    }
  }

  Future<void> markCompleted(String downloadId) async {
    for (final trackId in _trackIds(downloadId)) {
      await _localDataSource.updateDownloadSession(
        trackId,
        {'status': 'completed'},
      );
    }
  }

  Future<void> deleteForDownload(String downloadId) async {
    for (final trackId in _trackIds(downloadId)) {
      await _localDataSource.deleteDownloadSession(trackId);
      // This is intentionally explicit as well as relying on the SQL
      // cascade, because some existing installations may not have foreign
      // keys enabled on their SQLite connection.
      await _localDataSource.deleteDownloadChunks(trackId);
    }
  }

  List<String> _trackIds(String downloadId) => [
        downloadId,
        '${downloadId}_video',
        '${downloadId}_audio',
      ];

}

extension on DownloadSession {
  DownloadSession copyWithProgress({
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
