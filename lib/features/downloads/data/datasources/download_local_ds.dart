import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/supabase_client.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/utils/device_info_helper.dart';
import '../../domain/entities/downloaded_lesson.dart';

/// Local data source for download operations.
///
/// Handles file system operations and local database interactions.
class DownloadLocalDataSource {
  final StorageService _storageService;
  final Uuid _uuid;
  final String? Function() _currentUserId;
  final String Function() _deviceFingerprint;

  /// [currentUserId] and [deviceFingerprint] default to reading the real
  /// Supabase session / device fingerprint, and exist as constructor
  /// parameters purely so tests can inject fixed values instead of
  /// depending on Supabase/device-info being initialized. See
  /// `offline_policy_engine.dart` for how these values are enforced at
  /// playback time (P6.19/P6.20 account & device binding).
  DownloadLocalDataSource(
    this._storageService, {
    String? Function()? currentUserId,
    String Function()? deviceFingerprint,
  })  : _uuid = const Uuid(),
        _currentUserId = currentUserId ?? _defaultCurrentUserId,
        _deviceFingerprint = deviceFingerprint ?? _defaultDeviceFingerprint;

  static String? _defaultCurrentUserId() {
    try {
      return SupabaseService.client.auth.currentUser?.id;
    } catch (_) {
      // Supabase not initialized yet (e.g. background isolate) — treat as
      // "no account" rather than crashing an insert/query.
      return null;
    }
  }

  static String _defaultDeviceFingerprint() {
    try {
      return DeviceInfoHelper.fingerprint;
    } catch (_) {
      // DeviceInfoHelper.init() hasn't run yet — fail safe with a value
      // that will never match a previously stored device_id.
      return '';
    }
  }

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
  ///
  /// Binds the row to the currently signed-in account and this device
  /// (P6.19/P6.20) so it can later be authorized correctly by
  /// `OfflinePolicyEngine` and filtered correctly by [getDownloads].
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
      'user_id': _currentUserId(),
      'device_id': _deviceFingerprint(),
    });
  }

  /// Gets all downloads from the local database.
  ///
  /// Scoped to the current account by default (see
  /// `StorageService.getDownloadedLessons`) so a different account signed
  /// into this device never sees another account's download tiles. Pass
  /// `scopeToCurrentUser: false` for internal/debug tooling that
  /// deliberately needs every row regardless of owner.
  Future<List<Map<String, dynamic>>> getDownloads({
    bool scopeToCurrentUser = true,
  }) async {
    return await _storageService.getDownloadedLessons(
      ownerUserId: scopeToCurrentUser ? _currentUserId() : null,
    );
  }

  /// Returns every download bound to an account other than [currentUserId].
  /// See `OfflineAccountGuard`.
  Future<List<Map<String, dynamic>>> getDownloadsOwnedByOthers(
    String currentUserId,
  ) async {
    return await _storageService.getDownloadsOwnedByOthers(currentUserId);
  }

  /// Gets a download by lesson ID.
  ///
  /// Scoped to the current account by default (see `getDownloads` above and
  /// `StorageService.getDownloadByLessonId`'s doc comment for why) so the
  /// "already downloaded" check in `DownloadRepositoryImpl.startDownload`
  /// can't be tripped by a leftover row belonging to a previously
  /// signed-in account on this device.
  Future<Map<String, dynamic>?> getDownloadByLessonId(
    String lessonId, {
    bool scopeToCurrentUser = true,
  }) async {
    return await _storageService.getDownloadByLessonId(
      lessonId,
      ownerUserId: scopeToCurrentUser ? _currentUserId() : null,
    );
  }

  /// Gets a download by its ID.
  Future<Map<String, dynamic>?> getDownloadById(String id) async {
    return await _storageService.getDownloadById(
      id,
      ownerUserId: _currentUserId(),
    );
  }

  /// Re-verifies [id]'s tamper-evidence signature against its current
  /// field values (P6.22/P6.23). See `StorageService.verifyDownloadSignature`
  /// for exactly what `true`/`false` mean — used by `OfflinePolicyEngine`.
  Future<bool> verifyDownloadIntegrity(String id) async {
    return await _storageService.verifyDownloadSignature(id);
  }

  /// Gets downloads by course ID.
  Future<List<Map<String, dynamic>>> getDownloadsByCourse(String courseId) async {
    return await _storageService.getDownloadsByCourse(
      courseId,
      ownerUserId: _currentUserId(),
    );
  }

  /// Gets downloads by status.
  Future<List<Map<String, dynamic>>> getDownloadsByStatus(String status) async {
    return await _storageService.getDownloadsByStatus(
      status,
      ownerUserId: _currentUserId(),
    );
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
    return await _storageService.getExpiredDownloads(
      ownerUserId: _currentUserId(),
    );
  }

  /// Gets total storage used.
  Future<int> getTotalStorageUsed() async {
    return await _storageService.getTotalStorageUsed(
      ownerUserId: _currentUserId(),
    );
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
