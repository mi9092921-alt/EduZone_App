/// Durable identity and aggregate state for one download operation.
class DownloadSession {
  const DownloadSession({
    required this.downloadId,
    required this.lessonId,
    required this.courseId,
    required this.contentVersion,
    required this.quality,
    required this.trackType,
    required this.totalBytes,
    required this.chunkSize,
    required this.totalChunks,
    required this.completedBytes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.sourceIdentity,
    required this.entitlementId,
    required this.expiresAt,
    required this.encryptionVersion,
    required this.containerVersion,
  });

  final String downloadId;
  final String lessonId;
  final String courseId;
  final String contentVersion;
  final String quality;
  final String trackType;
  final int totalBytes;
  final int chunkSize;
  final int totalChunks;
  final int completedBytes;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String sourceIdentity;
  final String entitlementId;
  final DateTime? expiresAt;
  final int encryptionVersion;
  final int containerVersion;

  Map<String, dynamic> toMap() => {
        'download_id': downloadId,
        'lesson_id': lessonId,
        'course_id': courseId,
        'content_version': contentVersion,
        'quality': quality,
        'track_type': trackType,
        'total_bytes': totalBytes,
        'chunk_size': chunkSize,
        'total_chunks': totalChunks,
        'completed_bytes': completedBytes,
        'status': status,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'source_identity': sourceIdentity,
        'entitlement_id': entitlementId,
        'expires_at': expiresAt?.millisecondsSinceEpoch,
        'encryption_version': encryptionVersion,
        'container_version': containerVersion,
      };

  factory DownloadSession.fromMap(Map<String, dynamic> map) {
    DateTime? dateFrom(Object? value) => value == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(value as int);

    return DownloadSession(
      downloadId: map['download_id'] as String,
      lessonId: map['lesson_id'] as String,
      courseId: map['course_id'] as String,
      contentVersion: map['content_version'] as String? ?? '',
      quality: map['quality'] as String,
      trackType: map['track_type'] as String,
      totalBytes: map['total_bytes'] as int,
      chunkSize: map['chunk_size'] as int,
      totalChunks: map['total_chunks'] as int,
      completedBytes: map['completed_bytes'] as int,
      status: map['status'] as String,
      createdAt: dateFrom(map['created_at'])!,
      updatedAt: dateFrom(map['updated_at'])!,
      sourceIdentity: map['source_identity'] as String,
      entitlementId: map['entitlement_id'] as String,
      expiresAt: dateFrom(map['expires_at']),
      encryptionVersion: map['encryption_version'] as int,
      containerVersion: map['container_version'] as int,
    );
  }
}
