import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/storage_service.dart';
import '../../domain/entities/downloaded_lesson.dart';

/// Local data source for download operations.
///
/// Handles file system operations and local database interactions.
class DownloadLocalDataSource {
  final StorageService _storageService;
  final Uuid _uuid;

  DownloadLocalDataSource(this._storageService) : _uuid = const Uuid();

  /// Gets the downloads directory for the app.
  Future<Directory> getDownloadsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${appDir.path}/downloads');
    
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    
    return downloadsDir;
  }

  /// Creates a unique file path for a video download.
  ///
  /// [ext] is the real container extension of the source format (e.g.
  /// `mp4`, `webm`, `mkv`) and is embedded in the file name — e.g.
  /// `lesson123_720p.webm.enc` — so that after decryption the player can
  /// recover the original container via `detectContainerExt()` instead of
  /// assuming every download is mp4.
  Future<String> createFilePath({
    required String lessonId,
    required String quality,
    String ext = 'mp4',
  }) async {
    final downloadsDir = await getDownloadsDirectory();
    final safeExt = _sanitizeExt(ext);
    final fileName = '${lessonId}_$quality.$safeExt.enc';
    return '${downloadsDir.path}/$fileName';
  }

  /// Creates a unique file path for a separate audio track download.
  ///
  /// Used for dual-track downloads (video-only format + separate audio).
  /// [ext] is the real container extension of the audio track (e.g. `m4a`,
  /// `webm`/`weba`, `opus`) — see [createFilePath] for why this matters.
  Future<String> createAudioFilePath({
    required String lessonId,
    required String quality,
    String ext = 'm4a',
  }) async {
    final downloadsDir = await getDownloadsDirectory();
    final safeExt = _sanitizeExt(ext);
    final fileName = '${lessonId}_${quality}_audio.$safeExt.enc';
    return '${downloadsDir.path}/$fileName';
  }

  /// Keeps only safe, expected characters in a container extension before
  /// it's used as part of a file name — defends against an unexpected or
  /// malformed `ext` value from the backend response ending up as a path
  /// traversal or otherwise invalid file name segment.
  String _sanitizeExt(String ext) {
    final cleaned = ext.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return cleaned.isEmpty ? 'mp4' : cleaned;
  }

  /// Inserts a download record into the local database.
  Future<void> insertDownload(DownloadedLesson download) async {
    await _storageService.insertDownload({
      'id': download.id,
      'lesson_id': download.lessonId,
      'course_id': download.courseId,
      'course_title': download.courseTitle,
      'title': download.title,
      'local_path': download.localPath,
      'encrypted_path': download.encryptedPath,
      'audio_path': download.audioPath,
      'video_url': download.videoUrl,
      'audio_url': download.audioUrl,
      'quality': download.quality.label,
      'file_size': download.fileSize,
      'download_status': download.status.name,
      'progress': download.progress,
      'downloaded_at': download.downloadedAt.millisecondsSinceEpoch,
      'expires_at': download.expiresAt.millisecondsSinceEpoch,
      'checksum': download.checksum,
      'last_accessed_at': download.lastAccessedAt?.millisecondsSinceEpoch,
    });
  }

  /// Gets all downloads from the local database.
  Future<List<Map<String, dynamic>>> getDownloads() async {
    return await _storageService.getDownloadedLessons();
  }

  /// Gets a download by lesson ID.
  Future<Map<String, dynamic>?> getDownloadByLessonId(String lessonId) async {
    return await _storageService.getDownloadByLessonId(lessonId);
  }

  /// Gets a download by its ID.
  Future<Map<String, dynamic>?> getDownloadById(String id) async {
    return await _storageService.getDownloadById(id);
  }

  /// Gets downloads by course ID.
  Future<List<Map<String, dynamic>>> getDownloadsByCourse(String courseId) async {
    return await _storageService.getDownloadsByCourse(courseId);
  }

  /// Gets downloads by status.
  Future<List<Map<String, dynamic>>> getDownloadsByStatus(String status) async {
    return await _storageService.getDownloadsByStatus(status);
  }

  /// Updates download status.
  Future<void> updateDownloadStatus(String id, String status) async {
    await _storageService.updateDownloadStatus(id, status);
  }

  /// Updates download progress.
  Future<void> updateProgress(String id, double progress) async {
    await _storageService.updateProgress(id, progress);
  }

  /// Updates multiple fields of a download.
  Future<void> updateDownload(String id, Map<String, dynamic> updates) async {
    await _storageService.updateDownload(id, updates);
  }

  /// Updates last accessed timestamp.
  Future<void> updateLastAccessed(String id) async {
    await _storageService.updateLastAccessed(id);
  }

  /// Deletes a download record from the database.
  Future<void> deleteDownload(String id) async {
    await _storageService.deleteDownload(id);
  }

  /// Gets expired downloads.
  Future<List<Map<String, dynamic>>> getExpiredDownloads() async {
    return await _storageService.getExpiredDownloads();
  }

  /// Gets total storage used.
  Future<int> getTotalStorageUsed() async {
    return await _storageService.getTotalStorageUsed();
  }

  /// Deletes the encrypted file for a download.
  Future<void> deleteEncryptedFile(String encryptedPath) async {
    final file = File(encryptedPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Checks if a file exists at the given path.
  Future<bool> fileExists(String path) async {
    return await File(path).exists();
  }

  /// Gets the size of a file.
  Future<int> getFileSize(String path) async {
    final file = File(path);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  /// Generates a unique download ID.
  String generateDownloadId() {
    return _uuid.v4();
  }
}
