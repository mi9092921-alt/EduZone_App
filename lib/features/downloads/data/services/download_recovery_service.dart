import 'dart:io';

import '../../domain/entities/download_chunk.dart';
import '../../domain/entities/download_session.dart';
import '../datasources/download_local_ds.dart';

class DownloadRecoveryReport {
  const DownloadRecoveryReport({
    required this.sessionsScanned,
    required this.chunksReset,
    required this.chunksInvalidated,
  });

  final int sessionsScanned;
  final int chunksReset;
  final int chunksInvalidated;
}

/// Reconciles durable manifest state with encrypted files after process death.
///
/// This service never trusts a `verified` SQLite row by itself. It checks that
/// the corresponding encrypted record can at least fit at its deterministic
/// offset in the file. Cryptographic authentication remains the responsibility
/// of the existing encrypted playback/index validation path.
class DownloadRecoveryService {
  DownloadRecoveryService({required DownloadLocalDataSource localDataSource})
      : _localDataSource = localDataSource;

  final DownloadLocalDataSource _localDataSource;

  Future<DownloadRecoveryReport> reconcile() async {
    final sessions = await _localDataSource.getDownloadSessions();
    var chunksReset = 0;
    var chunksInvalidated = 0;

    for (final session in sessions) {
      final chunks = await _localDataSource.getDownloadChunks(
        session.downloadId,
      );
      final file = await _resolveEncryptedFile(session);

      for (final chunk in chunks) {
        if (chunk.state == 'verified') {
          final valid = file != null && await _hasRecord(file, chunk);
          if (!valid) {
            await _localDataSource.updateDownloadChunk(
              session.downloadId,
              chunk.chunkIndex,
              {
                'state': 'failed',
                'downloaded_bytes': 0,
                'last_error': 'Verified chunk is missing or truncated',
              },
            );
            chunksInvalidated++;
          }
        } else if (chunk.state == 'fetching' ||
            chunk.state == 'encrypting' ||
            chunk.state == 'persisted') {
          await _localDataSource.updateDownloadChunk(
            session.downloadId,
            chunk.chunkIndex,
            {
              'state': 'pending',
              'downloaded_bytes': 0,
              'last_error': null,
            },
          );
          chunksReset++;
        }
      }

      if (session.status == 'downloading') {
        await _localDataSource.updateDownloadSession(
          session.downloadId,
          {'status': 'pending'},
        );
      }
    }

    return DownloadRecoveryReport(
      sessionsScanned: sessions.length,
      chunksReset: chunksReset,
      chunksInvalidated: chunksInvalidated,
    );
  }

  Future<File?> _resolveEncryptedFile(DownloadSession session) async {
    final rootId = session.downloadId
        .replaceFirst(RegExp(r'_(video|audio)$'), '');
    final row = await _localDataSource.getDownloadById(
      rootId,
      scopeToCurrentUser: false,
    );
    if (row == null) return null;

    final path = session.trackType == 'audio'
        ? row['audio_path'] as String?
        : row['encrypted_path'] as String?;
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    return await file.exists() ? file : null;
  }

  Future<bool> _hasRecord(File file, DownloadChunk chunk) async {
    final requiredLength = chunk.encryptedOffset + chunk.encryptedLength;
    return await file.length() >= requiredLength;
  }
}
