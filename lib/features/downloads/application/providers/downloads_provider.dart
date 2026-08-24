import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/logging/logging_providers.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/providers/storage_provider.dart';
import '../../../../core/security/secure_storage_config.dart';
import '../../../../core/services/encryption_service.dart';
import '../../data/datasources/download_local_ds.dart';
import '../../data/datasources/download_remote_ds.dart';
import '../../data/repositories/download_repository_impl.dart';
import '../../data/services/download_manager.dart';
import '../../data/services/download_manifest_service.dart';
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
  return EncryptionService(hardenedSecureStorage);
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
    manifestService: DownloadManifestService(
      localDataSource: ref.watch(downloadLocalDataSourceProvider),
    ),
    // P8.13/Section 15 telemetry — wires download failure outcomes into
    // the same EventBus → AuditHandler pipeline already used by
    // auth/courses/todo/offline-playback (see DownloadFailedEvent).
    eventBus: ref.watch(eventBusProvider),
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
  int _buildGeneration = 0;
  int _loadGeneration = 0;

  bool _isCurrent(int generation, int loadGeneration) {
    return ref.mounted &&
        generation == _buildGeneration &&
        loadGeneration == _loadGeneration;
  }

  @override
  Future<List<DownloadedLesson>> build() async {
    final generation = ++_buildGeneration;
    final repository = ref.watch(downloadRepositoryProvider);
    final subscription = repository.changeStream.listen((_) async {
      if (!ref.mounted || generation != _buildGeneration) return;

      ref.invalidate(totalStorageUsedProvider);
      final loadGeneration = ++_loadGeneration;
      final next = await AsyncValue.guard(() => _loadDownloads(repository));
      if (_isCurrent(generation, loadGeneration)) state = next;
    });
    ref.onDispose(() {
      ++_buildGeneration;
      ++_loadGeneration;
      subscription.cancel();
    });
    return _loadDownloads(repository);
  }

  Future<List<DownloadedLesson>> _loadDownloads(
    DownloadRepository repository,
  ) async {
    final result = await repository.getDownloads();
    return result.fold((failure) {
      debugPrint('❌ _loadDownloads failed: $failure');
      throw failure;
    }, (downloads) => downloads);
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
    final generation = _buildGeneration;
    final useCase = ref.read(startDownloadUseCaseProvider);
    final result = await useCase.call(
      lessonId: lessonId,
      courseId: courseId,
      courseTitle: courseTitle,
      title: title,
      videoUrl: videoUrl,
      quality: quality,
    );

    // Guard: provider may have been disposed while we were awaiting.
    if (!ref.mounted || generation != _buildGeneration) return;

    await result.fold((failure) {
      state = AsyncError(failure, StackTrace.current);
      // Re-expose failure so the calling widget can show the error.
      Error.throwWithStackTrace(failure, StackTrace.current);
    }, (_) => refresh());
  }

  /// Pauses an active download.
  ///
  /// Throws a [Failure] if the pause request could not be completed.
  Future<void> pauseDownload(String downloadId) async {
    final generation = _buildGeneration;
    final useCase = ref.read(pauseDownloadUseCaseProvider);
    final result = await useCase.call(downloadId);

    // Guard: provider may have been disposed while we were awaiting.
    if (!ref.mounted || generation != _buildGeneration) return;

    await result.fold((failure) {
      state = AsyncError(failure, StackTrace.current);
      // Re-expose failure so the calling widget can show the error.
      Error.throwWithStackTrace(failure, StackTrace.current);
    }, (_) => refresh());
  }

  /// Resumes a paused download.
  ///
  /// Throws a [Failure] if the resume request could not be completed.
  Future<void> resumeDownload(String downloadId) async {
    final generation = _buildGeneration;
    final useCase = ref.read(resumeDownloadUseCaseProvider);
    final result = await useCase.call(downloadId);

    if (!ref.mounted || generation != _buildGeneration) return;

    await result.fold((failure) {
      state = AsyncError(failure, StackTrace.current);
      Error.throwWithStackTrace(failure, StackTrace.current);
    }, (_) => refresh());
  }

  /// Cancels a download.
  ///
  /// Throws a [Failure] if the cancel request could not be completed.
  Future<void> cancelDownload(String downloadId) async {
    final generation = _buildGeneration;
    final useCase = ref.read(cancelDownloadUseCaseProvider);
    final result = await useCase.call(downloadId);

    if (!ref.mounted || generation != _buildGeneration) return;

    await result.fold((failure) {
      state = AsyncError(failure, StackTrace.current);
      Error.throwWithStackTrace(failure, StackTrace.current);
    }, (_) => refresh());
  }

  /// Deletes a downloaded lesson.
  ///
  /// Throws a [Failure] if the delete request could not be completed.
  Future<void> deleteDownload(String downloadId) async {
    final generation = _buildGeneration;
    final useCase = ref.read(deleteDownloadUseCaseProvider);
    final result = await useCase.call(downloadId);

    if (!ref.mounted || generation != _buildGeneration) return;

    await result.fold((failure) {
      state = AsyncError(failure, StackTrace.current);
      Error.throwWithStackTrace(failure, StackTrace.current);
    }, (_) => refresh());
  }

  /// Cleans up expired downloads.
  ///
  /// Throws a [Failure] if the cleanup could not be completed.
  Future<void> cleanupExpired() async {
    final generation = _buildGeneration;
    final useCase = ref.read(cleanupExpiredDownloadsUseCaseProvider);
    final result = await useCase.call();

    if (!ref.mounted || generation != _buildGeneration) return;

    await result.fold((failure) {
      state = AsyncError(failure, StackTrace.current);
      Error.throwWithStackTrace(failure, StackTrace.current);
    }, (_) => refresh());
  }

  /// Refreshes the downloads list without showing a loading spinner.
  Future<void> refresh() async {
    final generation = _buildGeneration;
    final repository = ref.read(downloadRepositoryProvider);
    final loadGeneration = ++_loadGeneration;
    final next = await AsyncValue.guard(() => _loadDownloads(repository));
    if (_isCurrent(generation, loadGeneration)) state = next;
  }
}

// ─── Session cleanup ─────────────────────────────────────────────────────────

/// Invalidates every user-scoped provider owned by the `downloads` feature.
/// Called by [Auth.logout]. When you add a new user-scoped provider to this
/// file, add it here too.
///
/// [downloadsProvider] and [totalStorageUsedProvider] are declared
/// `keepAlive: true` and cache the previous account's downloaded-lesson list
/// (titles, course names, video URLs) and storage total in memory. Neither
/// was previously invalidated anywhere in the codebase — including here,
/// this feature was entirely absent from `invalidateAllUserScopedProviders`
/// (lib/app/session/session_invalidation.dart) — so a second account
/// signing in on the same device without a full app restart could see the
/// first account's in-memory download list on the Downloads screen before
/// any explicit refresh occurred. This is a direct violation of the
/// project's account-isolation requirement (EduZone_Offline_Download_
/// Security_Trusted_Playback_Architecture.md, P6.20 "Account Switching":
/// "we want to prevent User B from seeing User A's offline videos") and of
/// the general auth-cache-isolation rule that user-scoped caches must not
/// survive logout.
///
/// [downloadRepositoryProvider] (and the service/data-source providers it
/// composes: [encryptionServiceProvider], [downloadManagerProvider],
/// [downloadLocalDataSourceProvider], [downloadRemoteDataSourceProvider])
/// is deliberately NOT invalidated here. It owns the single long-lived
/// [DownloadRepositoryImpl] broadcast change stream that
/// [DownloadsNotifier.build] subscribes to and that in-flight background
/// downloads depend on; tearing it down on logout would cancel downloads
/// that are still actively writing to disk. Persisted on-disk entitlement
/// (license/key/file) isolation across accounts is already handled
/// separately and unconditionally by `OfflineAccountGuard` at the next
/// login (see `Auth.login` in auth_provider.dart), independent of this
/// in-memory cache invalidation.
void invalidateDownloadsProviders(Ref ref) {
  ref.invalidate(downloadsProvider);
  ref.invalidate(totalStorageUsedProvider);
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
  final result = await ref
      .watch(downloadRepositoryProvider)
      .getTotalStorageUsed();
  return result.fold((failure) => 0, (total) => total);
}

// ─── Download by Lesson ID Provider ────────────────────────────────────────────

/// Provider for getting a download by lesson ID.
@riverpod
Future<DownloadedLesson?> downloadByLessonId(Ref ref, String lessonId) async {
  final result = await ref
      .watch(downloadRepositoryProvider)
      .getDownloadByLessonId(lessonId);
  return result.fold((failure) => null, (download) => download);
}

/// Provider for getting a download by its own download ID.
@riverpod
Future<DownloadedLesson?> downloadById(Ref ref, String downloadId) async {
  final result = await ref
      .watch(downloadRepositoryProvider)
      .getDownloadById(downloadId);
  return result.fold((failure) => null, (download) => download);
}
