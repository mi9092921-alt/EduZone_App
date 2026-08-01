import 'package:freezed_annotation/freezed_annotation.dart';
import 'download_enums.dart';

part 'download_progress.freezed.dart';
part 'download_progress.g.dart';

/// Domain entity representing download progress information.
///
/// Used to track real-time download progress for UI updates.
@freezed
abstract class DownloadProgress with _$DownloadProgress {
  const factory DownloadProgress({
    required String downloadId,
    required String lessonId,
    required int receivedBytes,
    required int totalBytes,
    @Default(0.0) double progress,
    required DownloadStatus status,
    int? downloadSpeed, // bytes per second
    int? estimatedTimeRemaining, // seconds
    String? errorMessage,
  }) = _DownloadProgress;

  factory DownloadProgress.fromJson(Map<String, dynamic> json) =>
      _$DownloadProgressFromJson(json);
}

/// Extension for DownloadProgress utility methods.
extension DownloadProgressExtension on DownloadProgress {
  /// Calculates progress percentage from bytes.
  static double calculateProgress(int received, int total) {
    if (total <= 0) return 0.0;
    return (received / total * 100).clamp(0.0, 100.0);
  }

  /// Formats bytes to human-readable string.
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Formats seconds to human-readable time string.
  static String formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${(seconds / 60).floor()}m ${(seconds % 60)}s';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }
}
