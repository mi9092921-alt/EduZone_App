import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/supabase_client.dart';
import '../../../../core/providers/storage_provider.dart';
import '../../../../core/services/encryption_service.dart';
import '../../data/datasources/download_local_ds.dart';
import '../../data/datasources/download_remote_ds.dart';
import '../../data/repositories/download_repository_impl.dart';
import '../../data/services/download_manager.dart';
import '../../domain/entities/download_enums.dart';
import '../../domain/entities/download_progress.dart';
import '../../domain/entities/downloaded_lesson.dart';
import '../../domain/repositories/download_repository.dart';
import '../../domain/usecases/cancel_download_usecase.dart';
import '../../domain/usecases/cleanup_expired_downloads_usecase.dart';
import '../../domain/usecases/delete_download_usecase.dart';
import '../../domain/usecases/pause_download_usecase.dart';
import '../../domain/usecases/resume_download_usecase.dart';
import '../../domain/usecases/start_download_usecase.dart';

part 'downloads_provider.g.dart';

// ─── Service Providers ───────────────────────────────────────────────────────

/// Provides the EncryptionService instance.
@Riverpod(keepAlive: true)
EncryptionService encryptionService(Ref ref) {
  return EncryptionService(const FlutterSecureStorage());
}

/// Provides the DownloadManager instance.
@Riverpod(keepAlive: true)
DownloadManager downloadManager(Ref ref) {
  return DownloadManager();
}

/// Provides the DownloadLocalDataSource instance.
@Riverpod(keepAlive: true)
DownloadLocalDataSource downloadLocalDataSource(Ref ref) {
  return DownloadLocalDataSource(ref.watch(storageServiceProvider));
}

/// Provides the DownloadRemoteDataSource instance.
@Riverpod(keepAlive: true)
DownloadRemoteDataSource downloadRemoteDataSource(Ref ref) {
  return DownloadRemoteDataSource(SupabaseService.client);
}

/// Provides the DownloadRepository instance.
///
/// keepAlive so the single [DownloadRepositoryImpl] (and its broadcast
/// [StreamController]) is never torn down while downloads are in flight.
@Riverpod(keepAlive: true)
DownloadRepository downloadRepository(Ref ref) {
  return DownloadRepositoryImpl(
    remoteDataSource: ref.watch(downloadRemoteDataSourceProvider),
    localDataSource: ref.watch(downloadLocalDataSourceProvider),
    downloadManager: ref.watch(downloadManagerProvider),
    encryptionService: ref.watch(encryptionServiceProvider),
  );
}

// ─── Use Case Providers ───────────────────────────────────────────────────────

/// Provides the StartDownloadUseCase instance.
@riverpod
StartDownloadUseCase startDownloadUseCase(Ref ref) {
  return StartDownloadUseCase(ref.watch(downloadRepositoryProvider));
}

/// Provides the PauseDownloadUseCase instance.
@riverpod
PauseDownloadUseCase pauseDownloadUseCase(Ref ref) {
  return PauseDownloadUseCase(ref.watch(downloadRepositoryProvider));
}

/// Provides the ResumeDownloadUseCase instance.
@riverpod
ResumeDownloadUseCase resumeDownloadUseCase(Ref ref) {
  return ResumeDownloadUseCase(ref.watch(downloadRepositoryProvider));
}

/// Provides the CancelDownloadUseCase instance.
@riverpod
CancelDownloadUseCase cancelDownloadUseCase(Ref ref) {
  return CancelDownloadUseCase(ref.watch(downloadRepositoryProvider));
}

/// Provides the DeleteDownloadUseCase instance.
@riverpod
DeleteDownloadUseCase deleteDownloadUseCase(Ref ref) {
  return DeleteDownloadUseCase(ref.watch(downloadRepositoryProvider));
}

/// Provides the CleanupExpiredDownloadsUseCase instance.
@riverpod
CleanupExpiredDownloadsUseCase cleanupExpiredDownloadsUseCase(Ref ref) {
  return CleanupExpiredDownloadsUseCase(ref.watch(downloadRepositoryProvider));
}

// ─── Downloads Notifier ───────────────────────────────────────────────────────

/// Notifier for managing the list of downloaded lessons.
@Riverpod(keepAlive: true)
class DownloadsNotifier extends _$DownloadsNotifier {
  @override
  Future<List<DownloadedLesson>> build() async {
    final repository = ref.watch(downloadRepositoryProvider);
    final subscription = repository.changeStream.listen((_) async {
      ref.invalidate(totalStorageUsedProvider);
      state = await AsyncValue.guard(() => _loadDownloads());
    });
    ref.onDispose(() => subscription.cancel());
    return _loadDownloads();
  }

  Future<List<DownloadedLesson>> _loadDownloads() async {
    final result = await ref.read(downloadRepositoryProvider).getDownloads();
    return result.fold(
      (failure) {
        debugPrint('❌ _loadDownloads failed: $failure');
        throw failure;
      },
      (downloads) => downloads,
    );
  }

  /// Starts a new download.
  ///
  /// Throws a [Failure] if the download could not be initiated.
  Future<void> startDownload({
    required String lessonId,
    required String courseId,
    required String courseTitle,
    required String title,
    required String videoUrl,
    required VideoQuality quality,
  }) async {
    // Do NOT mutate state here — setting AsyncLoading() would trigger a
    // provider rebuild which disposes this Ref before the await completes.
    // The calling UI already shows its own progress indicator (SnackBar).
    final result = await ref.read(startDownloadUseCaseProvider).call(
      lessonId: lessonId,
      courseId: courseId,
      courseTitle: courseTitle,
      title: title,
      videoUrl: videoUrl,
      quality: quality,
    );

    // Guard: provider may have been disposed while we were awaiting.
    if (!ref.mounted) return;

    await result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        // Re-expose failure so the calling widget can show the error.
        Error.throwWithStackTrace(failure, StackTrace.current);
      },
      (_) => refresh(),
    );
  }

  /// Pauses an active download.
  ///
  /// Throws a [Failure] if the pause request could not be completed.
  Future<void> pauseDownload(String downloadId) async {
    final result =
        await ref.read(pauseDownloadUseCaseProvider).call(downloadId);

    // Guard: provider may have been disposed while we were awaiting.
    if (!ref.mounted) return;

    await result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        // Re-expose failure so the calling widget can show the error.
        Error.throwWithStackTrace(failure, StackTrace.current);
      },
      (_) => refresh(),
    );
  }

  /// Resumes a paused download.
  ///
  /// Throws a [Failure] if the resume request could not be completed.
  Future<void> resumeDownload(String downloadId) async {
    final result =
        await ref.read(resumeDownloadUseCaseProvider).call(downloadId);

    if (!ref.mounted) return;

    await result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        Error.throwWithStackTrace(failure, StackTrace.current);
      },
      (_) => refresh(),
    );
  }

  /// Cancels a download.
  ///
  /// Throws a [Failure] if the cancel request could not be completed.
  Future<void> cancelDownload(String downloadId) async {
    final result =
        await ref.read(cancelDownloadUseCaseProvider).call(downloadId);

    if (!ref.mounted) return;

    await result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        Error.throwWithStackTrace(failure, StackTrace.current);
      },
      (_) => refresh(),
    );
  }

  /// Deletes a downloaded lesson.
  ///
  /// Throws a [Failure] if the delete request could not be completed.
  Future<void> deleteDownload(String downloadId) async {
    final result =
        await ref.read(deleteDownloadUseCaseProvider).call(downloadId);

    if (!ref.mounted) return;

    await result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        Error.throwWithStackTrace(failure, StackTrace.current);
      },
      (_) => refresh(),
    );
  }

  /// Cleans up expired downloads.
  ///
  /// Throws a [Failure] if the cleanup could not be completed.
  Future<void> cleanupExpired() async {
    final result =
        await ref.read(cleanupExpiredDownloadsUseCaseProvider).call();

    if (!ref.mounted) return;

    await result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        Error.throwWithStackTrace(failure, StackTrace.current);
      },
      (_) => refresh(),
    );
  }

  /// Refreshes the downloads list without showing a loading spinner.
  Future<void> refresh() async {
    final next = await AsyncValue.guard(() => _loadDownloads());
    if (ref.mounted) state = next;
  }
}

// ─── Download Progress Provider ───────────────────────────────────────────────

/// Stream provider for watching download progress.
@riverpod
Stream<DownloadProgress> downloadProgress(Ref ref, String downloadId) {
  return ref.watch(downloadRepositoryProvider).watchProgress(downloadId);
}

// ─── Storage Usage Provider ───────────────────────────────────────────────────

/// Provider for total storage used by downloads.
@riverpod
Future<int> totalStorageUsed(Ref ref) async {
  final result = await ref.watch(downloadRepositoryProvider).getTotalStorageUsed();
  return result.fold(
    (failure) => 0,
    (total) => total,
  );
}

// ─── Download by Lesson ID Provider ────────────────────────────────────────────

/// Provider for getting a download by lesson ID.
@riverpod
Future<DownloadedLesson?> downloadByLessonId(Ref ref, String lessonId) async {
  final result = await ref
      .watch(downloadRepositoryProvider)
      .getDownloadByLessonId(lessonId);
  return result.fold(
    (failure) => null,
    (download) => download,
  );
}

/// Provider for getting a download by its own download ID.
@riverpod
Future<DownloadedLesson?> downloadById(Ref ref, String downloadId) async {
  final result = await ref
      .watch(downloadRepositoryProvider)
      .getDownloadById(downloadId);
  return result.fold(
    (failure) => null,
    (download) => download,
  );
}
