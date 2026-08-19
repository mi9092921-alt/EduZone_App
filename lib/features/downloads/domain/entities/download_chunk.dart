/// Durable state for one planned encrypted chunk.
class DownloadChunk {
  const DownloadChunk({
    required this.downloadId,
    required this.chunkIndex,
    required this.plaintextStart,
    required this.plaintextLength,
    required this.encryptedOffset,
    required this.encryptedLength,
    required this.state,
    required this.downloadedBytes,
    required this.attempts,
    required this.checksum,
    required this.updatedAt,
    required this.lastError,
    required this.committedAt,
  });

  final String downloadId;
  final int chunkIndex;
  final int plaintextStart;
  final int plaintextLength;
  final int encryptedOffset;
  final int encryptedLength;
  final String state;
  final int downloadedBytes;
  final int attempts;
  final String? checksum;
  final DateTime updatedAt;
  final String? lastError;
  final DateTime? committedAt;

  Map<String, dynamic> toMap() => {
        'download_id': downloadId,
        'chunk_index': chunkIndex,
        'plaintext_start': plaintextStart,
        'plaintext_length': plaintextLength,
        'encrypted_offset': encryptedOffset,
        'encrypted_length': encryptedLength,
        'state': state,
        'downloaded_bytes': downloadedBytes,
        'attempts': attempts,
        'checksum': checksum,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'last_error': lastError,
        'committed_at': committedAt?.millisecondsSinceEpoch,
      };

  factory DownloadChunk.fromMap(Map<String, dynamic> map) {
    DateTime? dateFrom(Object? value) => value == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(value as int);

    return DownloadChunk(
      downloadId: map['download_id'] as String,
      chunkIndex: map['chunk_index'] as int,
      plaintextStart: map['plaintext_start'] as int,
      plaintextLength: map['plaintext_length'] as int,
      encryptedOffset: map['encrypted_offset'] as int,
      encryptedLength: map['encrypted_length'] as int,
      state: map['state'] as String,
      downloadedBytes: map['downloaded_bytes'] as int,
      attempts: map['attempts'] as int,
      checksum: map['checksum'] as String?,
      updatedAt: dateFrom(map['updated_at'])!,
      lastError: map['last_error'] as String?,
      committedAt: dateFrom(map['committed_at']),
    );
  }
}
