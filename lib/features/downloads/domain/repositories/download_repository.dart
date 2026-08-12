import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/download_enums.dart';
import '../entities/download_progress.dart';
import '../entities/downloaded_lesson.dart';

/// Repository contract for download operations.
///
/// Handles all download-related operations including:
/// - Starting, pausing, resuming, canceling downloads
/// - Managing download metadata
/// - Cleanup of expired downloads
abstract class DownloadRepository {
  /// Starts a new download for a lesson.
  Future<Either<Failure, DownloadedLesson>> startDownload({
    required String lessonId,
    required String courseId,
    required String courseTitle,
    required String title,
    required String videoUrl,
    required VideoQuality quality,
  });

  /// Pauses an active download.
  Future<Either<Failure, void>> pauseDownload(String downloadId);

  /// Resumes a paused download.
  Future<Either<Failure, void>> resumeDownload(String downloadId);

  /// Cancels an active or paused download.
  Future<Either<Failure, void>> cancelDownload(String downloadId);

  /// Deletes a downloaded lesson (removes file and database record).
  Future<Either<Failure, void>> deleteDownload(String downloadId);

  /// Gets all downloaded lessons.
  Future<Either<Failure, List<DownloadedLesson>>> getDownloads();

  /// Gets a download by lesson ID.
  Future<Either<Failure, DownloadedLesson?>> getDownloadByLessonId(
    String lessonId,
  );

  /// Gets a download by its own download ID.
  Future<Either<Failure, DownloadedLesson?>> getDownloadById(String downloadId);

  /// Gets downloads for a specific course.
  Future<Either<Failure, List<DownloadedLesson>>> getDownloadsByCourse(
    String courseId,
  );

  /// Gets downloads with a specific status.
  Future<Either<Failure, List<DownloadedLesson>>> getDownloadsByStatus(
    DownloadStatus status,
  );

  /// Watches download progress for a specific download.
  Stream<DownloadProgress> watchProgress(String downloadId);

  /// Gets expired downloads for cleanup.
  Future<Either<Failure, List<DownloadedLesson>>> getExpiredDownloads();

  /// Cleans up expired downloads (deletes files and records).
  Future<Either<Failure, int>> cleanupExpiredDownloads();

  /// Gets total storage used by downloads.
  Future<Either<Failure, int>> getTotalStorageUsed();

  /// Updates the last accessed timestamp for a download.
  Future<Either<Failure, void>> updateLastAccessed(String downloadId);

  /// Stream of database changes (inserted, updated status, deleted).
  Stream<void> get changeStream;
}
