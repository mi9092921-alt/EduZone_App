import '../../domain/entities/download_enums.dart';

class VideoInfo {
  final String title;
  final String? thumbnail;
  final int? duration;
  final String? channel;
  final int? viewCount;
  final AudioTrack? audio;
  final List<VideoFormat> formats;
  final String defaultDownloadQuality;
  final String source;
  final String platform;
  final int timeMs;

  VideoInfo({
    required this.title,
    this.thumbnail,
    this.duration,
    this.channel,
    this.viewCount,
    this.audio,
    required this.formats,
    required this.defaultDownloadQuality,
    required this.source,
    required this.platform,
    required this.timeMs,
  });

  VideoQuality get defaultQuality =>
      VideoQuality.fromLabel(defaultDownloadQuality);

  /// All quality levels for which at least one video format exists.
  ///
  /// Previously filtered to muxed-only (hasAudio && !requiresMerge), which
  /// excluded 720p/1080p because YouTube serves those as separate video+audio
  /// streams. Now all formats are considered; the download layer decides
  /// whether to use a single muxed file or a dual-track download.
  List<VideoQuality> get supportedQualities {
    final supportedLabels = formats
        .where((format) => format.quality.isNotEmpty)
        .map((format) => format.quality)
        .toSet();
    return VideoQuality.values
        .where((quality) => supportedLabels.contains(quality.label))
        .toList();
  }

  int? get estimatedSize720p {
    return getSizeForQuality(VideoQuality.p720.label);
  }

  /// Returns actual file size in bytes for the given quality label,
  /// or null if not available.
  ///
  /// For muxed formats, returns the video size directly.
  /// For formats that require merge, returns video size + audio track size.
  int? getSizeForQuality(String qualityLabel) {
    final matchingFormats = formats
        .where((format) => format.quality == qualityLabel)
        .toList();
    if (matchingFormats.isEmpty) return null;

    // Prefer muxed (hasAudio && !requiresMerge) if available for this quality
    final muxedFormats = matchingFormats
        .where((format) => format.hasAudio && !format.requiresMerge)
        .toList();
    final selectedFormat =
        muxedFormats.isNotEmpty ? muxedFormats.first : matchingFormats.first;
    return _combinedSizeFor(selectedFormat);
  }

  int? _combinedSizeFor(VideoFormat format) {
    final videoSize = format.sizeBytes;
    if (!format.requiresMerge) return videoSize;
    // For formats requiring merge, add audio track size
    final audioSize = format.audioSizeBytes ?? audio?.sizeBytes;
    if (videoSize == null && audioSize == null) return null;
    return (videoSize ?? 0) + (audioSize ?? 0);
  }

  /// Returns true if the given quality requires downloading a separate audio track.
  bool requiresDualTrackFor(String qualityLabel) {
    final muxed = formats.any(
      (f) => f.quality == qualityLabel && f.hasAudio && !f.requiresMerge,
    );
    return !muxed &&
        formats.any((f) => f.quality == qualityLabel && f.requiresMerge);
  }

  /// Returns the best video-only format for the given quality label.
  VideoFormat? getVideoFormatFor(String qualityLabel) {
    // Prefer muxed first
    final muxed = formats
        .where(
          (f) => f.quality == qualityLabel && f.hasAudio && !f.requiresMerge,
        )
        .toList();
    if (muxed.isNotEmpty) return muxed.first;

    // Fall back to video-only (requiresMerge)
    final videoOnly = formats
        .where((f) => f.quality == qualityLabel)
        .toList();
    return videoOnly.isNotEmpty ? videoOnly.first : null;
  }

  factory VideoInfo.fromJson(Map<String, dynamic> json) {
    return VideoInfo(
      title: json['title'] as String? ?? '',
      thumbnail: json['thumbnail'] as String?,
      duration: json['duration'] as int?,
      channel: json['channel'] as String?,
      viewCount: json['view_count'] as int?,
      audio: json['audio'] != null
          ? AudioTrack.fromJson(
              Map<String, dynamic>.from(json['audio'] as Map),
            )
          : null,
      formats: (json['formats'] as List<dynamic>?)
              ?.map(
                (item) => VideoFormat.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList() ??
          [],
      defaultDownloadQuality:
          json['default_download_quality'] as String? ?? '360p',
      source: json['source'] as String? ?? 'fresh',
      platform: json['platform'] as String? ?? 'YouTube',
      timeMs: json['time_ms'] as int? ?? 0,
    );
  }
}

class AudioTrack {
  final int? itag;
  final String url;
  final int? sizeBytes;
  final String ext;

  AudioTrack({
    this.itag,
    required this.url,
    this.sizeBytes,
    required this.ext,
  });

  factory AudioTrack.fromJson(Map<String, dynamic> json) {
    return AudioTrack(
      itag: json['itag'] as int?,
      url: json['url'] as String? ?? '',
      sizeBytes: _parseSize(json['size_bytes'] ?? json['size'] ?? json['audio_size']),
      ext: json['ext'] as String? ?? 'm4a',
    );
  }
}

class VideoFormat {
  final int? itag;
  final String quality;
  final int? height;
  final int? fps;
  final String ext;
  final int? sizeBytes;
  final bool hasAudio;
  final bool requiresMerge;
  final String videoUrl;
  final String? audioUrl;
  final int? audioSizeBytes;
  final String? audioExt;

  VideoFormat({
    this.itag,
    required this.quality,
    this.height,
    this.fps,
    required this.ext,
    this.sizeBytes,
    required this.hasAudio,
    required this.requiresMerge,
    required this.videoUrl,
    this.audioUrl,
    this.audioSizeBytes,
    this.audioExt,
  });

  factory VideoFormat.fromJson(Map<String, dynamic> json) {
    final audioUrl = (json['audio_url'] as String?)?.trim();
    return VideoFormat(
      itag: json['itag'] as int?,
      quality: json['quality'] as String? ?? json['quality_label'] as String? ?? '',
      height: json['height'] as int?,
      fps: json['fps'] as int?,
      ext: json['ext'] as String? ?? 'mp4',
      sizeBytes: _parseSize(json['size_bytes'] ?? json['size']),
      hasAudio: json['has_audio'] as bool? ?? false,
      requiresMerge: json['requires_merge'] as bool? ?? true,
      videoUrl: json['video_url'] as String? ?? json['url'] as String? ?? '',
      audioUrl: audioUrl == null || audioUrl.isEmpty ? null : audioUrl,
      audioSizeBytes: _parseSize(json['audio_size_bytes'] ?? json['audio_size']),
      audioExt: json['audio_ext'] as String?,
    );
  }
}

int? _parseSize(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    final pureNum = int.tryParse(value);
    if (pureNum != null) return pureNum;

    // Clean human-readable string (e.g., "~120.6 MB" -> "120.6 mb")
    final cleaned = value.replaceAll('~', '').trim().toLowerCase();

    // Match patterns like "120.6 mb" or "120mb"
    final regExp = RegExp(r'^([\d.]+)\s*([a-z]+)$');
    final match = regExp.firstMatch(cleaned);
    if (match != null) {
      final val = double.tryParse(match.group(1) ?? '');
      final unit = match.group(2);
      if (val != null && unit != null) {
        switch (unit) {
          case 'b':
            return val.toInt();
          case 'kb':
            return (val * 1024).toInt();
          case 'mb':
            return (val * 1024 * 1024).toInt();
          case 'gb':
            return (val * 1024 * 1024 * 1024).toInt();
          case 'tb':
            return (val * 1024 * 1024 * 1024 * 1024).toInt();
        }
      }
    }
  }
  return null;
}

class CourseAccessResult {
  final bool allowed;
  final DateTime? expiresAt;

  CourseAccessResult({
    required this.allowed,
    required this.expiresAt,
  });

  factory CourseAccessResult.fromJson(Map<String, dynamic> json) {
    return CourseAccessResult(
      allowed: json['allowed'] as bool? ?? false,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
    );
  }
}
