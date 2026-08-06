import 'package:flutter/foundation.dart';

import '../../domain/entities/download_enums.dart';
import '../datasources/download_local_ds.dart';
import '../datasources/download_remote_ds.dart';
import 'download_format_selector.dart';

/// Result of [DownloadLinkRefresher.refreshIfStale].
///
/// [videoUrl]/[audioUrl] are always populated — either the freshly fetched
/// links (when [refreshed] is true) or the original, unchanged links passed
/// in (when the link wasn't stale, there was no [DownloadLinkRefresher]
/// source URL to refresh from, or the refresh attempt failed).
class DownloadLinkRefreshResult {
  final String videoUrl;
  final String? audioUrl;
  final bool refreshed;

  const DownloadLinkRefreshResult({
    required this.videoUrl,
    this.audioUrl,
    required this.refreshed,
  });
}

/// Renews a download's server-provided video/audio links when they are old
/// enough to plausibly have expired.
///
/// Extracted from `DownloadRepositoryImpl.resumeDownload` (see ARCH-006 in
/// the architecture review): link-refresh is a self-contained piece of
/// logic — "if the stored link is old, try to fetch a fresh one from the
/// original source URL, and persist it" — that doesn't need any of
/// `resumeDownload`'s surrounding orchestration (encryption keys, download
/// manager state, background execution). Isolating it here lets it be unit
/// tested against a mocked [DownloadRemoteDataSource] / [DownloadLocalDataSource]
/// without spinning up the full repository.
class DownloadLinkRefresher {
  final DownloadRemoteDataSource _remoteDataSource;
  final DownloadLocalDataSource _localDataSource;
  final DownloadFormatSelector _formatSelector;

  /// Server links have a TTL of ~6 hours. A link is treated as stale once
  /// it's older than this margin (1h safety margin baked into the 5h
  /// threshold below).
  static const Duration staleAfter = Duration(hours: 5);

  DownloadLinkRefresher({
    required DownloadRemoteDataSource remoteDataSource,
    required DownloadLocalDataSource localDataSource,
    DownloadFormatSelector? formatSelector,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _formatSelector = formatSelector ?? const DownloadFormatSelector();

  /// Refreshes [currentVideoUrl]/[currentAudioUrl] for [downloadId] when
  /// [linkValidatedAt] is older than [staleAfter] and [sourceUrl] is
  /// available to re-resolve against.
  ///
  /// On success, persists the new links and validation timestamp via the
  /// local data source and returns them. On failure (network error, no
  /// source URL, or link not actually stale yet) returns the original,
  /// unchanged URLs — the subsequent download attempt will surface a
  /// 401/403 itself if the link truly has expired, rather than failing
  /// silently here.
  Future<DownloadLinkRefreshResult> refreshIfStale({
    required String downloadId,
    required String currentVideoUrl,
    required String? currentAudioUrl,
    required String? sourceUrl,
    required DateTime? linkValidatedAt,
    required VideoQuality quality,
  }) async {
    final linkStale = linkValidatedAt == null ||
        DateTime.now().difference(linkValidatedAt) > staleAfter;

    if (!linkStale || sourceUrl == null || sourceUrl.isEmpty) {
      return DownloadLinkRefreshResult(
        videoUrl: currentVideoUrl,
        audioUrl: currentAudioUrl,
        refreshed: false,
      );
    }

    try {
      final freshInfo = await _remoteDataSource.getVideoInfo(sourceUrl);
      final freshSelected = _formatSelector.select(freshInfo, quality);
      final refreshedVideoUrl = freshSelected.videoFormat.videoUrl;
      final refreshedAudioUrl = freshSelected.audioTrack?.url;

      await _localDataSource.updateDownload(downloadId, {
        'video_url': refreshedVideoUrl,
        'audio_url': ?refreshedAudioUrl,
        'link_validated_at': DateTime.now().millisecondsSinceEpoch,
      });

      if (kDebugMode) {
        debugPrint(
          '🔄 DownloadLinkRefresher: refreshed stale server link for $downloadId',
        );
      }

      return DownloadLinkRefreshResult(
        videoUrl: refreshedVideoUrl,
        audioUrl: refreshedAudioUrl,
        refreshed: true,
      );
    } catch (e) {
      // Refresh failed — proceed with the stored (possibly stale) URL.
      if (kDebugMode) {
        debugPrint(
          '⚠️ DownloadLinkRefresher: link refresh failed, using stored URL: $e',
        );
      }
      return DownloadLinkRefreshResult(
        videoUrl: currentVideoUrl,
        audioUrl: currentAudioUrl,
        refreshed: false,
      );
    }
  }
}
