import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/download_enums.dart';
import '../../domain/entities/downloaded_lesson.dart';
import '../datasources/download_local_ds.dart';

/// Handles all **read-only** queries against the local downloads database.
///
/// Extracted from `DownloadRepositoryImpl` (see ARCH-005 in the
/// architecture review): the original class mixed download
/// execution/encryption (stateful — owns `_progressControllers`,
/// `_pausedDownloads`, `_cancelledDownloads`, an active `DownloadManager`
/// session map) with plain "read a row, map it to an entity" queries that
/// touch none of that state. Splitting the second group out here reduces
/// `DownloadRepositoryImpl` to the parts that actually need its mutable
/// state, and makes these queries testable without mocking encryption or
/// download-manager collaborators.
///
/// `DownloadRepositoryImpl` composes this service and delegates its
/// query-shaped methods to it; the public `DownloadRepository` interface
/// is unchanged.
class DownloadQueryService {
  final DownloadLocalDataSource _localDataSource;

  DownloadQueryService(this._localDataSource);

  Future<Either<Failure, List<DownloadedLesson>>> getDownloads() async {
    try {
      final downloadsData = await _localDataSource.getDownloads();
      if (kDebugMode) {
        debugPrint('[DownloadQueryService] getDownloads: raw rows count=${downloadsData.length}');
      }
      final downloads = <DownloadedLesson>[];
      for (final data in downloadsData) {
        try {
          downloads.add(_mapToEntity(data));
        } catch (e, stack) {
          debugPrint(
            '⚠️ Skipping corrupt download record '
            '(id=${data['id']}): $e\n$stack',
          );
        }
      }
      if (kDebugMode) {
        debugPrint('[DownloadQueryService] getDownloads: returning ${downloads.length} entities');
      }
      return Right(downloads);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Future<Either<Failure, DownloadedLesson?>> getDownloadByLessonId(
    String lessonId,
  ) async {
    try {
      final data = await _localDataSource.getDownloadByLessonId(lessonId);
      if (data == null) {
        return const Right(null);
      }
      return Right(_mapToEntity(data));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Future<Either<Failure, DownloadedLesson?>> getDownloadById(
    String downloadId,
  ) async {
    try {
      final data = await _localDataSource.getDownloadById(downloadId);
      if (data == null) {
        return const Right(null);
      }
      return Right(_mapToEntity(data));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Future<Either<Failure, List<DownloadedLesson>>> getDownloadsByCourse(
    String courseId,
  ) async {
    try {
      final downloadsData = await _localDataSource.getDownloadsByCourse(courseId);
      final downloads = downloadsData.map((data) => _mapToEntity(data)).toList();
      return Right(downloads);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Future<Either<Failure, List<DownloadedLesson>>> getDownloadsByStatus(
    DownloadStatus status,
  ) async {
    try {
      final downloadsData = await _localDataSource.getDownloadsByStatus(status.name);
      final downloads = downloadsData.map((data) => _mapToEntity(data)).toList();
      return Right(downloads);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Future<Either<Failure, List<DownloadedLesson>>> getExpiredDownloads() async {
    try {
      final expiredData = await _localDataSource.getExpiredDownloads();
      final expired = <DownloadedLesson>[];
      for (final data in expiredData) {
        try {
          expired.add(_mapToEntity(data));
        } catch (e) {
          debugPrint(
            '⚠️ Skipping corrupt expired download record '
            '(id=${data['id']}): $e',
          );
        }
      }
      return Right(expired);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Future<Either<Failure, int>> getTotalStorageUsed() async {
    try {
      final totalBytes = await _localDataSource.getTotalStorageUsed();
      return Right(totalBytes);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> updateLastAccessed(String downloadId) async {
    try {
      await _localDataSource.updateLastAccessed(downloadId);
      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  // ---------------------------------------------------------------------------
  // Using `as int` directly causes a silent TypeError that the catch block
  // swallows, producing an empty downloads list even though the file exists.
  // ---------------------------------------------------------------------------

  /// Converts any numeric value stored in SQLite to [int].
  /// Throws a descriptive [FormatException] when the field is missing or of
  /// an unexpected type so that the caller can log the exact record.
  static int _toInt(Map<String, dynamic> row, String key) {
    final v = row[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final parsed = int.tryParse(v);
      if (parsed != null) return parsed;
    }
    throw FormatException(
      'Field "$key" has unexpected type ${v.runtimeType} ' // check-ignore
      '(value=$v) for record id=${row['id']}', // check-ignore
    );
  }

  /// Same as [_toInt] but returns [null] when the column is SQL NULL.
  static int? _toIntOrNull(Map<String, dynamic> row, String key) {
    final v = row[key];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  DownloadedLesson _mapToEntity(Map<String, dynamic> data) {
    return DownloadedLesson(
      id: data['id'] as String,
      lessonId: data['lesson_id'] as String,
      courseId: data['course_id'] as String,
      courseTitle: data['course_title'] as String? ?? '',
      title: data['title'] as String,
      localPath: data['local_path'] as String,
      encryptedPath: data['encrypted_path'] as String,
      audioPath: data['audio_path'] as String?,
      videoUrl: data['video_url'] as String? ?? '',
      audioUrl: data['audio_url'] as String?,
      quality: VideoQuality.fromLabel(data['quality'] as String? ?? '720p'),
      // ↓ was: `data['file_size'] as int` — crashes when sqflite returns double
      fileSize: _toInt(data, 'file_size'),
      status: DownloadStatus.values.firstWhere(
        (s) => s.name == data['download_status'],
        orElse: () => DownloadStatus.pending,
      ),
      progress: (data['progress'] as num?)?.toDouble() ?? 0.0,
      // ↓ was: `data['downloaded_at'] as int` — same double-cast crash
      downloadedAt: DateTime.fromMillisecondsSinceEpoch(
        _toInt(data, 'downloaded_at'),
      ),
      // ↓ was: `data['expires_at'] as int` — same double-cast crash
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        _toInt(data, 'expires_at'),
      ),
      checksum: data['checksum'] as String?,
      lastAccessedAt: _toIntOrNull(data, 'last_accessed_at') != null
          ? DateTime.fromMillisecondsSinceEpoch(
              _toIntOrNull(data, 'last_accessed_at')!,
            )
          : null,
    );
  }
}
