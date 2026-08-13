import 'dart:io';

import '../../../../core/services/encryption_service.dart';
import '../../data/datasources/download_local_ds.dart';

/// Enforces P6.20 ("Account Switching") of
/// `EduZone_Offline_Download_Security_Trusted_Playback_Architecture.md`:
/// a different account logging in on a shared device must never inherit,
/// see, or be able to play back a previous account's offline downloads.
///
/// [OfflinePolicyEngine] already denies *playback* of another account's
/// downloads, and `StorageService.getDownloadedLessons` already hides them
/// from the downloads list. This guard goes one step further and reclaims
/// the disk space by deleting the files, key, and row outright — called
/// from `features/auth` right after a successful login (via
/// `shared/cross_feature/downloads_shared.dart`, see `auth_provider.dart`).
///
/// Best-effort and intentionally non-blocking: a failure here must never
/// block login, and a missed purge on one login is retried on the next
/// one (nothing here is a single point of failure for reclaiming storage
/// or for the actual security boundary, which is [OfflinePolicyEngine]).
class OfflineAccountGuard {
  OfflineAccountGuard({
    required DownloadLocalDataSource localDataSource,
    required EncryptionService encryptionService,
  })  : _localDataSource = localDataSource,
        _encryptionService = encryptionService;

  final DownloadLocalDataSource _localDataSource;
  final EncryptionService _encryptionService;

  /// Physically deletes every local download (encrypted file + `.idx`
  /// sidecar + `.tmp` partial + secure-storage key + DB row) whose
  /// `user_id` is set and does not match [currentUserId].
  ///
  /// Downloads with no owner (legacy, pre-account-binding rows) are left
  /// untouched — those are adopted lazily by `OfflinePolicyEngine` on
  /// first playback instead of being treated as belonging to someone else.
  ///
  /// Returns the number of downloads purged.
  Future<int> purgeDownloadsForOtherAccounts(String currentUserId) async {
    final others =
        await _localDataSource.getDownloadsOwnedByOthers(currentUserId);
    var purged = 0;

    for (final row in others) {
      final id = row['id'] as String?;
      if (id == null || id.isEmpty) continue;

      for (final basePath in [
        row['encrypted_path'] as String?,
        row['audio_path'] as String?,
      ]) {
        if (basePath == null || basePath.isEmpty) continue;
        for (final variant in [basePath, '$basePath.tmp', '$basePath.idx']) {
          try {
            final file = File(variant);
            if (await file.exists()) await file.delete();
          } catch (_) {
            // Non-fatal: even if a file is left behind, it's unreadable
            // once the key is deleted below.
          }
        }
      }

      try {
        await _encryptionService.deleteKey(id);
      } catch (_) {}

      try {
        await _localDataSource.deleteDownload(id);
        purged++;
      } catch (_) {
        // Leave the row for the next login/cleanup pass to retry.
      }
    }

    return purged;
  }
}
