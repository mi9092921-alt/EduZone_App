import 'package:freezed_annotation/freezed_annotation.dart';
import 'download_enums.dart';

part 'downloaded_lesson.freezed.dart';
part 'downloaded_lesson.g.dart';

/// Domain entity representing a downloaded lesson.
///
/// Contains metadata about the download including file paths,
/// encryption info, status, progress, and expiration.
@freezed
abstract class DownloadedLesson with _$DownloadedLesson {
  const factory DownloadedLesson({
    required String id,
    required String lessonId,
    required String courseId,
    @Default('') String courseTitle,
    required String title,
    required String localPath,
    required String encryptedPath,
    /// Path to the encrypted audio file; null for muxed (single-file) downloads.
    String? audioPath,
    required String videoUrl,
    /// URL of the separate audio track; null for muxed formats.
    String? audioUrl,
    required VideoQuality quality,
    required int fileSize,
    required DownloadStatus status,
    @Default(0.0) double progress,
    required DateTime downloadedAt,
    required DateTime expiresAt,
    String? checksum,
    DateTime? lastAccessedAt,
  }) = _DownloadedLesson;

  factory DownloadedLesson.fromJson(Map<String, dynamic> json) =>
      _$DownloadedLessonFromJson(json);

  factory DownloadedLesson.skeleton() => DownloadedLesson(
        id: 'skeleton',
        lessonId: 'skeleton',
        courseId: 'skeleton',
        courseTitle: 'Loading...',
        title: 'Loading...',
        localPath: '',
        encryptedPath: '',
        videoUrl: '',
        quality: VideoQuality.p720,
        fileSize: 0,
        status: DownloadStatus.pending,
        downloadedAt: DateTime(2024),
        expiresAt: DateTime(2025),
      );
}
