import 'package:freezed_annotation/freezed_annotation.dart';

/// Status of a download operation.
enum DownloadStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('downloading')
  downloading,
  @JsonValue('paused')
  paused,
  @JsonValue('completed')
  completed,
  @JsonValue('failed')
  failed,
}

/// Video quality options for downloads.
enum VideoQuality {
  @JsonValue('144p')
  p144('144p'),
  @JsonValue('240p')
  p240('240p'),
  @JsonValue('360p')
  p360('360p'),
  @JsonValue('480p')
  p480('480p'),
  @JsonValue('720p')
  p720('720p'),
  @JsonValue('1080p')
  p1080('1080p');

  final String label;
  const VideoQuality(this.label);

  /// Parses a quality label into a VideoQuality enum.
  static VideoQuality fromLabel(String label) {
    return VideoQuality.values.firstWhere(
      (quality) => quality.label == label,
      orElse: () => VideoQuality.p720,
    );
  }

  /// Gets the estimated file size multiplier relative to 720p.
  double get sizeMultiplier {
    switch (this) {
      case VideoQuality.p144:
        return 0.1;
      case VideoQuality.p240:
        return 0.2;
      case VideoQuality.p360:
        return 0.4;
      case VideoQuality.p480:
        return 0.6;
      case VideoQuality.p720:
        return 1.0;
      case VideoQuality.p1080:
        return 1.8;
    }
  }

  /// Gets the display name for the quality.
  String get displayName => label;
}
