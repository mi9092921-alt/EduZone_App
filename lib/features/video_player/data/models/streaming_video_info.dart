class StreamingVideoInfo {
  final String title;
  final String? thumbnail;
  final int? duration;
  final String? channel;
  final int? viewCount;
  final StreamingAudioTrack? audio;
  final List<StreamingFormat> formats;
  final String defaultQuality;
  final DateTime? cacheExpiresAt;

  StreamingVideoInfo({
    required this.title,
    this.thumbnail,
    this.duration,
    this.channel,
    this.viewCount,
    this.audio,
    required this.formats,
    required this.defaultQuality,
    this.cacheExpiresAt,
  });

  factory StreamingVideoInfo.fromJson(Map<String, dynamic> json) {
    return StreamingVideoInfo(
      title: json['title'] as String? ?? '',
      thumbnail: json['thumbnail'] as String?,
      duration: json['duration'] as int?,
      channel: json['channel'] as String?,
      viewCount: json['view_count'] as int?,
      audio: json['audio'] != null
          ? StreamingAudioTrack.fromJson(Map<String, dynamic>.from(json['audio'] as Map))
          : null,
      formats: (json['formats'] as List<dynamic>?)
              ?.map((item) => StreamingFormat.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ))
              .where((f) => f.videoUrl.isNotEmpty)
              .toList() ??
          [],
      defaultQuality: json['default_download_quality'] as String? ?? '360p',
      cacheExpiresAt: json['cache_expires_at'] != null
          ? DateTime.tryParse(json['cache_expires_at'] as String)
          : null,
    );
  }
}

class StreamingAudioTrack {
  final int? itag;
  final String url;
  final int? sizeBytes;
  final String ext;

  StreamingAudioTrack({
    this.itag,
    required this.url,
    this.sizeBytes,
    required this.ext,
  });

  factory StreamingAudioTrack.fromJson(Map<String, dynamic> json) {
    return StreamingAudioTrack(
      itag: json['itag'] as int?,
      url: json['url'] as String? ?? '',
      sizeBytes: _parseSize(json['size_bytes'] ?? json['size'] ?? json['audio_size']),
      ext: json['ext'] as String? ?? 'm4a',
    );
  }
}

class StreamingFormat {
  final int? itag;
  final String quality;
  final int? height;
  final int? fps;
  final String ext;
  final int? sizeBytes;
  final bool hasAudio;
  final bool requiresMerge;
  final String videoUrl;

  StreamingFormat({
    this.itag,
    required this.quality,
    this.height,
    this.fps,
    required this.ext,
    this.sizeBytes,
    required this.hasAudio,
    required this.requiresMerge,
    required this.videoUrl,
  });

  factory StreamingFormat.fromJson(Map<String, dynamic> json) {
    return StreamingFormat(
      itag: json['itag'] as int?,
      quality: json['quality'] as String? ?? json['quality_label'] as String? ?? '',
      height: json['height'] as int?,
      fps: json['fps'] as int?,
      ext: json['ext'] as String? ?? 'mp4',
      sizeBytes: _parseSize(json['size_bytes'] ?? json['size']),
      hasAudio: json['has_audio'] as bool? ?? false,
      requiresMerge: json['requires_merge'] as bool? ?? true,
      videoUrl: json['video_url'] as String? ?? json['url'] as String? ?? '',
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
