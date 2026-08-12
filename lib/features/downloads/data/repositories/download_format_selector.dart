import '../../data/models/video_info.dart';
import '../../domain/entities/download_enums.dart';

/// Holds the video format selected for download and, when the format
/// requires a separate audio stream, the corresponding [AudioTrack].
///
/// When [audioTrack] is null the download is a single muxed file.
/// When [audioTrack] is non-null the download runs two parallel streams.
class SelectedFormats {
  final VideoFormat videoFormat;
  final AudioTrack? audioTrack;

  const SelectedFormats(this.videoFormat, {this.audioTrack});

  /// True when a separate audio file must be downloaded alongside the video.
  bool get isDualTrack => audioTrack != null;
}

/// Picks the best [VideoFormat] (and, when needed, [AudioTrack]) for a
/// requested [VideoQuality] out of the formats returned by the extractor.
///
/// Extracted from `DownloadRepositoryImpl` (see ARCH-006 in the
/// architecture review): the selection logic is pure — it only reads a
/// [VideoInfo] and a [VideoQuality] and returns a [SelectedFormats] — but
/// it used to live as private methods on the repository, which meant it
/// could only be exercised indirectly through `startDownload`. It is also
/// needed as-is by the link-refresh flow in `resumeDownload` (to re-select
/// a format against a freshly fetched [VideoInfo]), which previously forced
/// that flow to reach back into the repository's private `_selectFormats`.
/// Both callers now share this single, independently testable class.
class DownloadFormatSelector {
  const DownloadFormatSelector();

  /// Selects the format to download for [quality] out of [videoInfo].
  ///
  /// Preference order:
  /// 1. Exact-quality muxed format (single file, no merge needed).
  /// 2. Exact-quality video-only format + a matching audio track.
  /// 3. Closest available quality among all formats (preferring muxed).
  ///
  /// Throws an [Exception] when [videoInfo] has no usable formats at all.
  SelectedFormats select(VideoInfo videoInfo, VideoQuality quality) {
    // 1. Prefer an exact-quality muxed format (single file, no merge needed)
    final exactMuxed = videoInfo.formats
        .where(
          (f) =>
              f.quality == quality.label && f.hasAudio && !f.requiresMerge,
        )
        .toList();
    if (exactMuxed.isNotEmpty) {
      return SelectedFormats(exactMuxed.first);
    }

    // 2. Check for an exact-quality video-only format + audio track
    final exactVideo = videoInfo.formats
        .where((f) => f.quality == quality.label && f.requiresMerge)
        .toList();
    if (exactVideo.isNotEmpty) {
      final exactFormat = exactVideo.first;
      final audioTrack = _audioTrackForFormat(exactFormat, videoInfo);
      if (audioTrack != null) {
        return SelectedFormats(exactFormat, audioTrack: audioTrack);
      }
    }
    if (exactVideo.isNotEmpty) {
      // No audio track from API — treat as best-effort single file
      return SelectedFormats(exactVideo.first);
    }

    // 3. Fall back: find closest quality among ALL formats
    //    Prefer muxed over merge if qualities are equidistant.
    final allFormats =
        videoInfo.formats.where((f) => f.quality.isNotEmpty).toList();
    if (allFormats.isEmpty) {
      throw Exception('No video formats available for this lesson.'); // check-ignore
    }

    allFormats.sort((a, b) {
      final aQ = VideoQuality.fromLabel(a.quality);
      final bQ = VideoQuality.fromLabel(b.quality);
      final aDiff = (aQ.index - quality.index).abs();
      final bDiff = (bQ.index - quality.index).abs();
      if (aDiff != bDiff) return aDiff.compareTo(bDiff);
      // Prefer muxed (lower index = already has audio)
      final aIsMuxed = a.hasAudio && !a.requiresMerge ? 0 : 1;
      final bIsMuxed = b.hasAudio && !b.requiresMerge ? 0 : 1;
      return aIsMuxed.compareTo(bIsMuxed);
    });

    final best = allFormats.first;
    final needsAudio = !best.hasAudio || best.requiresMerge;
    return SelectedFormats(
      best,
      audioTrack: needsAudio ? _audioTrackForFormat(best, videoInfo) : null,
    );
  }

  AudioTrack? _audioTrackForFormat(VideoFormat format, VideoInfo videoInfo) {
    final formatAudioUrl = format.audioUrl;
    if (formatAudioUrl != null && formatAudioUrl.isNotEmpty) {
      return AudioTrack(
        url: formatAudioUrl,
        sizeBytes: format.audioSizeBytes,
        ext: format.audioExt ?? videoInfo.audio?.ext ?? 'm4a',
      );
    }
    return videoInfo.audio;
  }
}
