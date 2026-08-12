// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloads_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the EncryptionService instance.

@ProviderFor(encryptionService)
final encryptionServiceProvider = EncryptionServiceProvider._();

/// Provides the EncryptionService instance.

final class EncryptionServiceProvider
    extends
        $FunctionalProvider<
          EncryptionService,
          EncryptionService,
          EncryptionService
        >
    with $Provider<EncryptionService> {
  /// Provides the EncryptionService instance.
  EncryptionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'encryptionServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$encryptionServiceHash();

  @$internal
  @override
  $ProviderElement<EncryptionService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EncryptionService create(Ref ref) {
    return encryptionService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EncryptionService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EncryptionService>(value),
    );
  }
}

String _$encryptionServiceHash() => r'f808f8ea2933177ce53275ce0640bb46caebbb59';

/// Provides the DownloadManager instance.

@ProviderFor(downloadManager)
final downloadManagerProvider = DownloadManagerProvider._();

/// Provides the DownloadManager instance.

final class DownloadManagerProvider
    extends
        $FunctionalProvider<DownloadManager, DownloadManager, DownloadManager>
    with $Provider<DownloadManager> {
  /// Provides the DownloadManager instance.
  DownloadManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadManagerHash();

  @$internal
  @override
  $ProviderElement<DownloadManager> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DownloadManager create(Ref ref) {
    return downloadManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadManager>(value),
    );
  }
}

String _$downloadManagerHash() => r'f95756f0af0a9a063f97832a612b5bbd610205c3';

/// Provides the DownloadLocalDataSource instance.

@ProviderFor(downloadLocalDataSource)
final downloadLocalDataSourceProvider = DownloadLocalDataSourceProvider._();

/// Provides the DownloadLocalDataSource instance.

final class DownloadLocalDataSourceProvider
    extends
        $FunctionalProvider<
          DownloadLocalDataSource,
          DownloadLocalDataSource,
          DownloadLocalDataSource
        >
    with $Provider<DownloadLocalDataSource> {
  /// Provides the DownloadLocalDataSource instance.
  DownloadLocalDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadLocalDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadLocalDataSourceHash();

  @$internal
  @override
  $ProviderElement<DownloadLocalDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DownloadLocalDataSource create(Ref ref) {
    return downloadLocalDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadLocalDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadLocalDataSource>(value),
    );
  }
}

String _$downloadLocalDataSourceHash() =>
    r'b8cb1f3a4dac9533b8e3452a30744ba216ecd9f6';

/// Provides the DownloadRemoteDataSource instance.

@ProviderFor(downloadRemoteDataSource)
final downloadRemoteDataSourceProvider = DownloadRemoteDataSourceProvider._();

/// Provides the DownloadRemoteDataSource instance.

final class DownloadRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          DownloadRemoteDataSource,
          DownloadRemoteDataSource,
          DownloadRemoteDataSource
        >
    with $Provider<DownloadRemoteDataSource> {
  /// Provides the DownloadRemoteDataSource instance.
  DownloadRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadRemoteDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<DownloadRemoteDataSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DownloadRemoteDataSource create(Ref ref) {
    return downloadRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadRemoteDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadRemoteDataSource>(value),
    );
  }
}

String _$downloadRemoteDataSourceHash() =>
    r'91755d1467168c353e9b1ddc9c5b2709cd4b662c';

/// Provides the DownloadRepository instance.
///
/// keepAlive so the single [DownloadRepositoryImpl] (and its broadcast
/// [StreamController]) is never torn down while downloads are in flight.

@ProviderFor(downloadRepository)
final downloadRepositoryProvider = DownloadRepositoryProvider._();

/// Provides the DownloadRepository instance.
///
/// keepAlive so the single [DownloadRepositoryImpl] (and its broadcast
/// [StreamController]) is never torn down while downloads are in flight.

final class DownloadRepositoryProvider
    extends
        $FunctionalProvider<
          DownloadRepository,
          DownloadRepository,
          DownloadRepository
        >
    with $Provider<DownloadRepository> {
  /// Provides the DownloadRepository instance.
  ///
  /// keepAlive so the single [DownloadRepositoryImpl] (and its broadcast
  /// [StreamController]) is never torn down while downloads are in flight.
  DownloadRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadRepositoryHash();

  @$internal
  @override
  $ProviderElement<DownloadRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DownloadRepository create(Ref ref) {
    return downloadRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadRepository>(value),
    );
  }
}

String _$downloadRepositoryHash() =>
    r'92439a3ca641b0beb1247c167ffb9a1d6cfd5595';

/// Provides the StartDownloadUseCase instance.

@ProviderFor(startDownloadUseCase)
final startDownloadUseCaseProvider = StartDownloadUseCaseProvider._();

/// Provides the StartDownloadUseCase instance.

final class StartDownloadUseCaseProvider
    extends
        $FunctionalProvider<
          StartDownloadUseCase,
          StartDownloadUseCase,
          StartDownloadUseCase
        >
    with $Provider<StartDownloadUseCase> {
  /// Provides the StartDownloadUseCase instance.
  StartDownloadUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'startDownloadUseCaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$startDownloadUseCaseHash();

  @$internal
  @override
  $ProviderElement<StartDownloadUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StartDownloadUseCase create(Ref ref) {
    return startDownloadUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StartDownloadUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StartDownloadUseCase>(value),
    );
  }
}

String _$startDownloadUseCaseHash() =>
    r'b2133900a273b7d752352c4085bc8a62d5ad13cb';

/// Provides the PauseDownloadUseCase instance.

@ProviderFor(pauseDownloadUseCase)
final pauseDownloadUseCaseProvider = PauseDownloadUseCaseProvider._();

/// Provides the PauseDownloadUseCase instance.

final class PauseDownloadUseCaseProvider
    extends
        $FunctionalProvider<
          PauseDownloadUseCase,
          PauseDownloadUseCase,
          PauseDownloadUseCase
        >
    with $Provider<PauseDownloadUseCase> {
  /// Provides the PauseDownloadUseCase instance.
  PauseDownloadUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pauseDownloadUseCaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pauseDownloadUseCaseHash();

  @$internal
  @override
  $ProviderElement<PauseDownloadUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PauseDownloadUseCase create(Ref ref) {
    return pauseDownloadUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PauseDownloadUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PauseDownloadUseCase>(value),
    );
  }
}

String _$pauseDownloadUseCaseHash() =>
    r'6c45e31ffb565610385c6452b7b84f6f56b101b6';

/// Provides the ResumeDownloadUseCase instance.

@ProviderFor(resumeDownloadUseCase)
final resumeDownloadUseCaseProvider = ResumeDownloadUseCaseProvider._();

/// Provides the ResumeDownloadUseCase instance.

final class ResumeDownloadUseCaseProvider
    extends
        $FunctionalProvider<
          ResumeDownloadUseCase,
          ResumeDownloadUseCase,
          ResumeDownloadUseCase
        >
    with $Provider<ResumeDownloadUseCase> {
  /// Provides the ResumeDownloadUseCase instance.
  ResumeDownloadUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'resumeDownloadUseCaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$resumeDownloadUseCaseHash();

  @$internal
  @override
  $ProviderElement<ResumeDownloadUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ResumeDownloadUseCase create(Ref ref) {
    return resumeDownloadUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ResumeDownloadUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ResumeDownloadUseCase>(value),
    );
  }
}

String _$resumeDownloadUseCaseHash() =>
    r'cf84ccd5c677d79c611a078353bd1c620733424f';

/// Provides the CancelDownloadUseCase instance.

@ProviderFor(cancelDownloadUseCase)
final cancelDownloadUseCaseProvider = CancelDownloadUseCaseProvider._();

/// Provides the CancelDownloadUseCase instance.

final class CancelDownloadUseCaseProvider
    extends
        $FunctionalProvider<
          CancelDownloadUseCase,
          CancelDownloadUseCase,
          CancelDownloadUseCase
        >
    with $Provider<CancelDownloadUseCase> {
  /// Provides the CancelDownloadUseCase instance.
  CancelDownloadUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cancelDownloadUseCaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cancelDownloadUseCaseHash();

  @$internal
  @override
  $ProviderElement<CancelDownloadUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CancelDownloadUseCase create(Ref ref) {
    return cancelDownloadUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CancelDownloadUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CancelDownloadUseCase>(value),
    );
  }
}

String _$cancelDownloadUseCaseHash() =>
    r'c7ee9a7bc7f26f0e5becc67c1e50d6c97dbc6c5a';

/// Provides the DeleteDownloadUseCase instance.

@ProviderFor(deleteDownloadUseCase)
final deleteDownloadUseCaseProvider = DeleteDownloadUseCaseProvider._();

/// Provides the DeleteDownloadUseCase instance.

final class DeleteDownloadUseCaseProvider
    extends
        $FunctionalProvider<
          DeleteDownloadUseCase,
          DeleteDownloadUseCase,
          DeleteDownloadUseCase
        >
    with $Provider<DeleteDownloadUseCase> {
  /// Provides the DeleteDownloadUseCase instance.
  DeleteDownloadUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deleteDownloadUseCaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deleteDownloadUseCaseHash();

  @$internal
  @override
  $ProviderElement<DeleteDownloadUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DeleteDownloadUseCase create(Ref ref) {
    return deleteDownloadUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeleteDownloadUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeleteDownloadUseCase>(value),
    );
  }
}

String _$deleteDownloadUseCaseHash() =>
    r'58ebf106babe31343b9aa8ca84b48abbb6dd4e05';

/// Provides the CleanupExpiredDownloadsUseCase instance.

@ProviderFor(cleanupExpiredDownloadsUseCase)
final cleanupExpiredDownloadsUseCaseProvider =
    CleanupExpiredDownloadsUseCaseProvider._();

/// Provides the CleanupExpiredDownloadsUseCase instance.

final class CleanupExpiredDownloadsUseCaseProvider
    extends
        $FunctionalProvider<
          CleanupExpiredDownloadsUseCase,
          CleanupExpiredDownloadsUseCase,
          CleanupExpiredDownloadsUseCase
        >
    with $Provider<CleanupExpiredDownloadsUseCase> {
  /// Provides the CleanupExpiredDownloadsUseCase instance.
  CleanupExpiredDownloadsUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cleanupExpiredDownloadsUseCaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cleanupExpiredDownloadsUseCaseHash();

  @$internal
  @override
  $ProviderElement<CleanupExpiredDownloadsUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CleanupExpiredDownloadsUseCase create(Ref ref) {
    return cleanupExpiredDownloadsUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CleanupExpiredDownloadsUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CleanupExpiredDownloadsUseCase>(
        value,
      ),
    );
  }
}

String _$cleanupExpiredDownloadsUseCaseHash() =>
    r'5c67845be77512cb34be068479ffd7fc56023c41';

/// Notifier for managing the list of downloaded lessons.

@ProviderFor(DownloadsNotifier)
final downloadsProvider = DownloadsNotifierProvider._();

/// Notifier for managing the list of downloaded lessons.
final class DownloadsNotifierProvider
    extends $AsyncNotifierProvider<DownloadsNotifier, List<DownloadedLesson>> {
  /// Notifier for managing the list of downloaded lessons.
  DownloadsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadsNotifierHash();

  @$internal
  @override
  DownloadsNotifier create() => DownloadsNotifier();
}

String _$downloadsNotifierHash() => r'b1b1e1e7c205990b9953be05309f120a77c73230';

/// Notifier for managing the list of downloaded lessons.

abstract class _$DownloadsNotifier
    extends $AsyncNotifier<List<DownloadedLesson>> {
  FutureOr<List<DownloadedLesson>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<DownloadedLesson>>, List<DownloadedLesson>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<DownloadedLesson>>,
                List<DownloadedLesson>
              >,
              AsyncValue<List<DownloadedLesson>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Stream provider for watching download progress.

@ProviderFor(downloadProgress)
final downloadProgressProvider = DownloadProgressFamily._();

/// Stream provider for watching download progress.

final class DownloadProgressProvider
    extends
        $FunctionalProvider<
          AsyncValue<DownloadProgress>,
          DownloadProgress,
          Stream<DownloadProgress>
        >
    with $FutureModifier<DownloadProgress>, $StreamProvider<DownloadProgress> {
  /// Stream provider for watching download progress.
  DownloadProgressProvider._({
    required DownloadProgressFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'downloadProgressProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$downloadProgressHash();

  @override
  String toString() {
    return r'downloadProgressProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<DownloadProgress> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<DownloadProgress> create(Ref ref) {
    final argument = this.argument as String;
    return downloadProgress(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DownloadProgressProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$downloadProgressHash() => r'de552f65061c3602fbede983a4408102d22c72be';

/// Stream provider for watching download progress.

final class DownloadProgressFamily extends $Family
    with $FunctionalFamilyOverride<Stream<DownloadProgress>, String> {
  DownloadProgressFamily._()
    : super(
        retry: null,
        name: r'downloadProgressProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Stream provider for watching download progress.

  DownloadProgressProvider call(String downloadId) =>
      DownloadProgressProvider._(argument: downloadId, from: this);

  @override
  String toString() => r'downloadProgressProvider';
}

/// Provider for total storage used by downloads.

@ProviderFor(totalStorageUsed)
final totalStorageUsedProvider = TotalStorageUsedProvider._();

/// Provider for total storage used by downloads.

final class TotalStorageUsedProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// Provider for total storage used by downloads.
  TotalStorageUsedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'totalStorageUsedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$totalStorageUsedHash();

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    return totalStorageUsed(ref);
  }
}

String _$totalStorageUsedHash() => r'ddcb542fac506e4e112ed62d2b958b095b0078fb';

/// Provider for getting a download by lesson ID.

@ProviderFor(downloadByLessonId)
final downloadByLessonIdProvider = DownloadByLessonIdFamily._();

/// Provider for getting a download by lesson ID.

final class DownloadByLessonIdProvider
    extends
        $FunctionalProvider<
          AsyncValue<DownloadedLesson?>,
          DownloadedLesson?,
          FutureOr<DownloadedLesson?>
        >
    with
        $FutureModifier<DownloadedLesson?>,
        $FutureProvider<DownloadedLesson?> {
  /// Provider for getting a download by lesson ID.
  DownloadByLessonIdProvider._({
    required DownloadByLessonIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'downloadByLessonIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$downloadByLessonIdHash();

  @override
  String toString() {
    return r'downloadByLessonIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<DownloadedLesson?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DownloadedLesson?> create(Ref ref) {
    final argument = this.argument as String;
    return downloadByLessonId(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DownloadByLessonIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$downloadByLessonIdHash() =>
    r'da580951c8b396f158087b426353e34b78775a19';

/// Provider for getting a download by lesson ID.

final class DownloadByLessonIdFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<DownloadedLesson?>, String> {
  DownloadByLessonIdFamily._()
    : super(
        retry: null,
        name: r'downloadByLessonIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for getting a download by lesson ID.

  DownloadByLessonIdProvider call(String lessonId) =>
      DownloadByLessonIdProvider._(argument: lessonId, from: this);

  @override
  String toString() => r'downloadByLessonIdProvider';
}

/// Provider for getting a download by its own download ID.

@ProviderFor(downloadById)
final downloadByIdProvider = DownloadByIdFamily._();

/// Provider for getting a download by its own download ID.

final class DownloadByIdProvider
    extends
        $FunctionalProvider<
          AsyncValue<DownloadedLesson?>,
          DownloadedLesson?,
          FutureOr<DownloadedLesson?>
        >
    with
        $FutureModifier<DownloadedLesson?>,
        $FutureProvider<DownloadedLesson?> {
  /// Provider for getting a download by its own download ID.
  DownloadByIdProvider._({
    required DownloadByIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'downloadByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$downloadByIdHash();

  @override
  String toString() {
    return r'downloadByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<DownloadedLesson?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DownloadedLesson?> create(Ref ref) {
    final argument = this.argument as String;
    return downloadById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DownloadByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$downloadByIdHash() => r'bea5e493f29eaf0ae2e2cc0d0248b8cc107db6b9';

/// Provider for getting a download by its own download ID.

final class DownloadByIdFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<DownloadedLesson?>, String> {
  DownloadByIdFamily._()
    : super(
        retry: null,
        name: r'downloadByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for getting a download by its own download ID.

  DownloadByIdProvider call(String downloadId) =>
      DownloadByIdProvider._(argument: downloadId, from: this);

  @override
  String toString() => r'downloadByIdProvider';
}
