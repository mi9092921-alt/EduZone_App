import 'dart:io';

import 'edz_local_proxy.dart';
import 'encryption_service.dart';

/// Fallback policy when streaming proxy fails: use full-file decrypt
/// (Option A chosen for compatibility and higher reliability).

/// Service responsible for preparing encrypted offline videos for playback.
///
/// This keeps decryption logic out of the presentation layer and ensures temp
/// files are cleaned up consistently.
class OfflinePlaybackService {
  OfflinePlaybackService({required EncryptionService encryptionService})
      : _encryptionService = encryptionService;

  final EncryptionService _encryptionService;
  EdzLocalProxy? _proxy;

  /// Starts a streaming proxy and returns the URI to pass to the player.
  Future<Uri> startStreamingProxy({
    required String downloadId,
    required String encryptedPath,
  }) async {
    final encryptionKey = await _encryptionService.retrieveKey(downloadId);
    if (encryptionKey == null || encryptionKey.isEmpty) {
      throw StateError('Encryption key not found for download $downloadId');
    }

    final encryptedFile = File(encryptedPath);
    final index = await loadOrBuildIndex(encryptedFile);

    // Recover the real container (mp4/webm/mkv/...) that was embedded in
    // the file name at download time, so the proxy serves an accurate
    // Content-Type instead of always claiming 'video/mp4'. For downloads
    // created before this fix (old file-naming scheme), this safely falls
    // back to 'mp4' — same as the previous hardcoded behavior.
    final containerExt = detectContainerExt(encryptedPath);
    final contentType = mimeTypeForContainerExt(containerExt);

    _proxy = EdzLocalProxy();
    final uri = await _proxy!.start(
      encryptedFile: encryptedFile,
      keyBase64: encryptionKey,
      index: index,
      contentType: contentType,
    );
    return uri;
  }

  Future<void> stopStreamingProxy() async {
    try {
      await _proxy?.stop();
    } finally {
      _proxy = null;
    }
  }

  Future<File> preparePlayableFile({
    required String downloadId,
    required String encryptedPath,
    required String outputPath,
  }) async {
    final encryptionKey = await _encryptionService.retrieveKey(downloadId);
    if (encryptionKey == null || encryptionKey.isEmpty) {
      throw StateError('Encryption key not found for download $downloadId');
    }

    final outputFile = File(outputPath);
    final tempFile = outputFile;

    try {
      await _encryptionService.decryptFile(
        File(encryptedPath),
        tempFile,
        encryptionKey,
      );
      return tempFile;
    } catch (error) {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    }
  }

  Future<void> cleanupTempFile(File file) async {
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {
        // Best effort cleanup for temp artifacts.
      }
    }
  }
}