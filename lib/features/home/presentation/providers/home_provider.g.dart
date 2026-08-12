// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(homeRemoteDataSource)
final homeRemoteDataSourceProvider = HomeRemoteDataSourceProvider._();

final class HomeRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          HomeRemoteDataSourceImpl,
          HomeRemoteDataSourceImpl,
          HomeRemoteDataSourceImpl
        >
    with $Provider<HomeRemoteDataSourceImpl> {
  HomeRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeRemoteDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<HomeRemoteDataSourceImpl> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  HomeRemoteDataSourceImpl create(Ref ref) {
    return homeRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HomeRemoteDataSourceImpl value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HomeRemoteDataSourceImpl>(value),
    );
  }
}

String _$homeRemoteDataSourceHash() =>
    r'168b47d05b2f1e491d825f6fc496647d169144b1';

@ProviderFor(homeRepository)
final homeRepositoryProvider = HomeRepositoryProvider._();

final class HomeRepositoryProvider
    extends $FunctionalProvider<HomeRepository, HomeRepository, HomeRepository>
    with $Provider<HomeRepository> {
  HomeRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeRepositoryHash();

  @$internal
  @override
  $ProviderElement<HomeRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HomeRepository create(Ref ref) {
    return homeRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HomeRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HomeRepository>(value),
    );
  }
}

String _$homeRepositoryHash() => r'f7a3b02614216fb8c1150138bb9587e6dc7b68e9';

@ProviderFor(resumeLesson)
final resumeLessonProvider = ResumeLessonProvider._();

final class ResumeLessonProvider
    extends
        $FunctionalProvider<
          AsyncValue<ResumeLesson?>,
          ResumeLesson?,
          FutureOr<ResumeLesson?>
        >
    with $FutureModifier<ResumeLesson?>, $FutureProvider<ResumeLesson?> {
  ResumeLessonProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'resumeLessonProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$resumeLessonHash();

  @$internal
  @override
  $FutureProviderElement<ResumeLesson?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ResumeLesson?> create(Ref ref) {
    return resumeLesson(ref);
  }
}

String _$resumeLessonHash() => r'bfe3e83f29a02d96b3a773d89375b93351b358f6';

@ProviderFor(recentCourses)
final recentCoursesProvider = RecentCoursesProvider._();

final class RecentCoursesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<HomeCourseSummary>>,
          List<HomeCourseSummary>,
          FutureOr<List<HomeCourseSummary>>
        >
    with
        $FutureModifier<List<HomeCourseSummary>>,
        $FutureProvider<List<HomeCourseSummary>> {
  RecentCoursesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentCoursesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentCoursesHash();

  @$internal
  @override
  $FutureProviderElement<List<HomeCourseSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<HomeCourseSummary>> create(Ref ref) {
    return recentCourses(ref);
  }
}

String _$recentCoursesHash() => r'4edd3a101e3e63fcf8c149653ba0fdd3ace7f0e0';

@ProviderFor(recentTodos)
final recentTodosProvider = RecentTodosProvider._();

final class RecentTodosProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<HomeTodoSummary>>,
          List<HomeTodoSummary>,
          FutureOr<List<HomeTodoSummary>>
        >
    with
        $FutureModifier<List<HomeTodoSummary>>,
        $FutureProvider<List<HomeTodoSummary>> {
  RecentTodosProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentTodosProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentTodosHash();

  @$internal
  @override
  $FutureProviderElement<List<HomeTodoSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<HomeTodoSummary>> create(Ref ref) {
    return recentTodos(ref);
  }
}

String _$recentTodosHash() => r'2d885e8fc1461b12f712d270806800463b0bb094';
