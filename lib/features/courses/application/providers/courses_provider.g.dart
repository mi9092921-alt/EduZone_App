// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'courses_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(coursesRemoteDataSource)
final coursesRemoteDataSourceProvider = CoursesRemoteDataSourceProvider._();

final class CoursesRemoteDataSourceProvider
    extends
        $FunctionalProvider<
          CoursesRemoteDataSourceImpl,
          CoursesRemoteDataSourceImpl,
          CoursesRemoteDataSourceImpl
        >
    with $Provider<CoursesRemoteDataSourceImpl> {
  CoursesRemoteDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coursesRemoteDataSourceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coursesRemoteDataSourceHash();

  @$internal
  @override
  $ProviderElement<CoursesRemoteDataSourceImpl> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CoursesRemoteDataSourceImpl create(Ref ref) {
    return coursesRemoteDataSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoursesRemoteDataSourceImpl value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoursesRemoteDataSourceImpl>(value),
    );
  }
}

String _$coursesRemoteDataSourceHash() =>
    r'b9c2395bfd12b7fd0ff42a79e0728c56c4f76bb2';

@ProviderFor(coursesRepository)
final coursesRepositoryProvider = CoursesRepositoryProvider._();

final class CoursesRepositoryProvider
    extends
        $FunctionalProvider<
          CoursesRepository,
          CoursesRepository,
          CoursesRepository
        >
    with $Provider<CoursesRepository> {
  CoursesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coursesRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coursesRepositoryHash();

  @$internal
  @override
  $ProviderElement<CoursesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CoursesRepository create(Ref ref) {
    return coursesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoursesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoursesRepository>(value),
    );
  }
}

String _$coursesRepositoryHash() => r'96dcd1bb2fac9b07ee3def61458ca8e9bab39de0';

@ProviderFor(getMyCourses)
final getMyCoursesProvider = GetMyCoursesProvider._();

final class GetMyCoursesProvider
    extends $FunctionalProvider<GetMyCourses, GetMyCourses, GetMyCourses>
    with $Provider<GetMyCourses> {
  GetMyCoursesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getMyCoursesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getMyCoursesHash();

  @$internal
  @override
  $ProviderElement<GetMyCourses> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GetMyCourses create(Ref ref) {
    return getMyCourses(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetMyCourses value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetMyCourses>(value),
    );
  }
}

String _$getMyCoursesHash() => r'9a1bb11514846c393334a6e9e18e0f1e550cddd3';

@ProviderFor(getCourseDetails)
final getCourseDetailsProvider = GetCourseDetailsProvider._();

final class GetCourseDetailsProvider
    extends
        $FunctionalProvider<
          GetCourseDetails,
          GetCourseDetails,
          GetCourseDetails
        >
    with $Provider<GetCourseDetails> {
  GetCourseDetailsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getCourseDetailsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getCourseDetailsHash();

  @$internal
  @override
  $ProviderElement<GetCourseDetails> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GetCourseDetails create(Ref ref) {
    return getCourseDetails(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetCourseDetails value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetCourseDetails>(value),
    );
  }
}

String _$getCourseDetailsHash() => r'e7399f4cf4938b4b97b5b2f8614a9759bbb3173e';

@ProviderFor(updateLessonProgress)
final updateLessonProgressProvider = UpdateLessonProgressProvider._();

final class UpdateLessonProgressProvider
    extends
        $FunctionalProvider<
          UpdateLessonProgress,
          UpdateLessonProgress,
          UpdateLessonProgress
        >
    with $Provider<UpdateLessonProgress> {
  UpdateLessonProgressProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateLessonProgressProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateLessonProgressHash();

  @$internal
  @override
  $ProviderElement<UpdateLessonProgress> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UpdateLessonProgress create(Ref ref) {
    return updateLessonProgress(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateLessonProgress value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateLessonProgress>(value),
    );
  }
}

String _$updateLessonProgressHash() =>
    r'0f650ea7ab02f2e297ac718794071b503bbbd4bd';

@ProviderFor(getLessonContent)
final getLessonContentProvider = GetLessonContentProvider._();

final class GetLessonContentProvider
    extends
        $FunctionalProvider<
          GetLessonContent,
          GetLessonContent,
          GetLessonContent
        >
    with $Provider<GetLessonContent> {
  GetLessonContentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getLessonContentProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getLessonContentHash();

  @$internal
  @override
  $ProviderElement<GetLessonContent> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GetLessonContent create(Ref ref) {
    return getLessonContent(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetLessonContent value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetLessonContent>(value),
    );
  }
}

String _$getLessonContentHash() => r'32b627dd80a7a18c280d45fca522cb09375f78dc';

@ProviderFor(enrollInCourse)
final enrollInCourseProvider = EnrollInCourseProvider._();

final class EnrollInCourseProvider
    extends $FunctionalProvider<EnrollInCourse, EnrollInCourse, EnrollInCourse>
    with $Provider<EnrollInCourse> {
  EnrollInCourseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'enrollInCourseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$enrollInCourseHash();

  @$internal
  @override
  $ProviderElement<EnrollInCourse> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EnrollInCourse create(Ref ref) {
    return enrollInCourse(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EnrollInCourse value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EnrollInCourse>(value),
    );
  }
}

String _$enrollInCourseHash() => r'bc6b7ffebed582568412250a0a9f130237c5cd1e';

@ProviderFor(getPublicCourses)
final getPublicCoursesProvider = GetPublicCoursesProvider._();

final class GetPublicCoursesProvider
    extends
        $FunctionalProvider<
          GetPublicCourses,
          GetPublicCourses,
          GetPublicCourses
        >
    with $Provider<GetPublicCourses> {
  GetPublicCoursesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getPublicCoursesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getPublicCoursesHash();

  @$internal
  @override
  $ProviderElement<GetPublicCourses> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GetPublicCourses create(Ref ref) {
    return getPublicCourses(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetPublicCourses value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetPublicCourses>(value),
    );
  }
}

String _$getPublicCoursesHash() => r'21fe42a430a0d95f7b6eb9449bb67e7ec90bbd72';

@ProviderFor(getUserSubscribedCourseIds)
final getUserSubscribedCourseIdsProvider =
    GetUserSubscribedCourseIdsProvider._();

final class GetUserSubscribedCourseIdsProvider
    extends
        $FunctionalProvider<
          GetUserSubscribedCourseIds,
          GetUserSubscribedCourseIds,
          GetUserSubscribedCourseIds
        >
    with $Provider<GetUserSubscribedCourseIds> {
  GetUserSubscribedCourseIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getUserSubscribedCourseIdsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getUserSubscribedCourseIdsHash();

  @$internal
  @override
  $ProviderElement<GetUserSubscribedCourseIds> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GetUserSubscribedCourseIds create(Ref ref) {
    return getUserSubscribedCourseIds(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetUserSubscribedCourseIds value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetUserSubscribedCourseIds>(value),
    );
  }
}

String _$getUserSubscribedCourseIdsHash() =>
    r'eca7effaf6143a899bdda7af5d8783f886a550ff';

@ProviderFor(getMyCourseEnrollment)
final getMyCourseEnrollmentProvider = GetMyCourseEnrollmentProvider._();

final class GetMyCourseEnrollmentProvider
    extends
        $FunctionalProvider<
          GetMyCourseEnrollment,
          GetMyCourseEnrollment,
          GetMyCourseEnrollment
        >
    with $Provider<GetMyCourseEnrollment> {
  GetMyCourseEnrollmentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getMyCourseEnrollmentProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getMyCourseEnrollmentHash();

  @$internal
  @override
  $ProviderElement<GetMyCourseEnrollment> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GetMyCourseEnrollment create(Ref ref) {
    return getMyCourseEnrollment(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetMyCourseEnrollment value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetMyCourseEnrollment>(value),
    );
  }
}

String _$getMyCourseEnrollmentHash() =>
    r'1d8026966237fae93266b496bae4fedd9e998a9c';

@ProviderFor(getCourseProgressSummary)
final getCourseProgressSummaryProvider = GetCourseProgressSummaryProvider._();

final class GetCourseProgressSummaryProvider
    extends
        $FunctionalProvider<
          GetCourseProgressSummary,
          GetCourseProgressSummary,
          GetCourseProgressSummary
        >
    with $Provider<GetCourseProgressSummary> {
  GetCourseProgressSummaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getCourseProgressSummaryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getCourseProgressSummaryHash();

  @$internal
  @override
  $ProviderElement<GetCourseProgressSummary> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GetCourseProgressSummary create(Ref ref) {
    return getCourseProgressSummary(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetCourseProgressSummary value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetCourseProgressSummary>(value),
    );
  }
}

String _$getCourseProgressSummaryHash() =>
    r'e1943a8fdf3045cca094fa36d3cff0cce644fe62';

@ProviderFor(getBookmarkedCourseIds)
final getBookmarkedCourseIdsProvider = GetBookmarkedCourseIdsProvider._();

final class GetBookmarkedCourseIdsProvider
    extends
        $FunctionalProvider<
          GetBookmarkedCourseIds,
          GetBookmarkedCourseIds,
          GetBookmarkedCourseIds
        >
    with $Provider<GetBookmarkedCourseIds> {
  GetBookmarkedCourseIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getBookmarkedCourseIdsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getBookmarkedCourseIdsHash();

  @$internal
  @override
  $ProviderElement<GetBookmarkedCourseIds> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GetBookmarkedCourseIds create(Ref ref) {
    return getBookmarkedCourseIds(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetBookmarkedCourseIds value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetBookmarkedCourseIds>(value),
    );
  }
}

String _$getBookmarkedCourseIdsHash() =>
    r'289e58a30f3a6336a832c52427d75c26a5a86c07';

@ProviderFor(toggleCourseBookmark)
final toggleCourseBookmarkProvider = ToggleCourseBookmarkProvider._();

final class ToggleCourseBookmarkProvider
    extends
        $FunctionalProvider<
          ToggleCourseBookmark,
          ToggleCourseBookmark,
          ToggleCourseBookmark
        >
    with $Provider<ToggleCourseBookmark> {
  ToggleCourseBookmarkProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'toggleCourseBookmarkProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$toggleCourseBookmarkHash();

  @$internal
  @override
  $ProviderElement<ToggleCourseBookmark> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ToggleCourseBookmark create(Ref ref) {
    return toggleCourseBookmark(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ToggleCourseBookmark value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ToggleCourseBookmark>(value),
    );
  }
}

String _$toggleCourseBookmarkHash() =>
    r'eeffdf85cf040e368e040a98894da9e93c04a0b3';

@ProviderFor(getCoursesByIds)
final getCoursesByIdsProvider = GetCoursesByIdsProvider._();

final class GetCoursesByIdsProvider
    extends
        $FunctionalProvider<GetCoursesByIds, GetCoursesByIds, GetCoursesByIds>
    with $Provider<GetCoursesByIds> {
  GetCoursesByIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getCoursesByIdsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getCoursesByIdsHash();

  @$internal
  @override
  $ProviderElement<GetCoursesByIds> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GetCoursesByIds create(Ref ref) {
    return getCoursesByIds(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetCoursesByIds value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetCoursesByIds>(value),
    );
  }
}

String _$getCoursesByIdsHash() => r'61ab10abe438c4a4438cdee82411097678480ef5';

@ProviderFor(myCourses)
final myCoursesProvider = MyCoursesProvider._();

final class MyCoursesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CourseEnrollment>>,
          List<CourseEnrollment>,
          FutureOr<List<CourseEnrollment>>
        >
    with
        $FutureModifier<List<CourseEnrollment>>,
        $FutureProvider<List<CourseEnrollment>> {
  MyCoursesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myCoursesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myCoursesHash();

  @$internal
  @override
  $FutureProviderElement<List<CourseEnrollment>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CourseEnrollment>> create(Ref ref) {
    return myCourses(ref);
  }
}

String _$myCoursesHash() => r'7d7ac92ebffcf2e268e6ff537264c5d970dd8cc4';

/// Returns whether the current user is enrolled in the given [courseId].
///
/// Returns [AsyncValue] to preserve loading and error states — callers can
/// show skeletons or fallback UI instead of silently defaulting to `false`.

@ProviderFor(isEnrolled)
final isEnrolledProvider = IsEnrolledFamily._();

/// Returns whether the current user is enrolled in the given [courseId].
///
/// Returns [AsyncValue] to preserve loading and error states — callers can
/// show skeletons or fallback UI instead of silently defaulting to `false`.

final class IsEnrolledProvider
    extends
        $FunctionalProvider<
          AsyncValue<bool>,
          AsyncValue<bool>,
          AsyncValue<bool>
        >
    with $Provider<AsyncValue<bool>> {
  /// Returns whether the current user is enrolled in the given [courseId].
  ///
  /// Returns [AsyncValue] to preserve loading and error states — callers can
  /// show skeletons or fallback UI instead of silently defaulting to `false`.
  IsEnrolledProvider._({
    required IsEnrolledFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'isEnrolledProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isEnrolledHash();

  @override
  String toString() {
    return r'isEnrolledProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AsyncValue<bool>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AsyncValue<bool> create(Ref ref) {
    final argument = this.argument as String;
    return isEnrolled(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<bool> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<bool>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IsEnrolledProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isEnrolledHash() => r'c66d1503c5904b4b2e2d0c2bf485628be3dfafe1';

/// Returns whether the current user is enrolled in the given [courseId].
///
/// Returns [AsyncValue] to preserve loading and error states — callers can
/// show skeletons or fallback UI instead of silently defaulting to `false`.

final class IsEnrolledFamily extends $Family
    with $FunctionalFamilyOverride<AsyncValue<bool>, String> {
  IsEnrolledFamily._()
    : super(
        retry: null,
        name: r'isEnrolledProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Returns whether the current user is enrolled in the given [courseId].
  ///
  /// Returns [AsyncValue] to preserve loading and error states — callers can
  /// show skeletons or fallback UI instead of silently defaulting to `false`.

  IsEnrolledProvider call(String courseId) =>
      IsEnrolledProvider._(argument: courseId, from: this);

  @override
  String toString() => r'isEnrolledProvider';
}

@ProviderFor(courseDetails)
final courseDetailsProvider = CourseDetailsFamily._();

final class CourseDetailsProvider
    extends $FunctionalProvider<AsyncValue<Course>, Course, FutureOr<Course>>
    with $FutureModifier<Course>, $FutureProvider<Course> {
  CourseDetailsProvider._({
    required CourseDetailsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'courseDetailsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$courseDetailsHash();

  @override
  String toString() {
    return r'courseDetailsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Course> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Course> create(Ref ref) {
    final argument = this.argument as String;
    return courseDetails(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CourseDetailsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$courseDetailsHash() => r'527147dd72136189a50894ddd87bc9763854bd5e';

final class CourseDetailsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Course>, String> {
  CourseDetailsFamily._()
    : super(
        retry: null,
        name: r'courseDetailsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CourseDetailsProvider call(String courseId) =>
      CourseDetailsProvider._(argument: courseId, from: this);

  @override
  String toString() => r'courseDetailsProvider';
}

@ProviderFor(lessonContent)
final lessonContentProvider = LessonContentFamily._();

final class LessonContentProvider
    extends
        $FunctionalProvider<
          AsyncValue<LessonContent>,
          LessonContent,
          FutureOr<LessonContent>
        >
    with $FutureModifier<LessonContent>, $FutureProvider<LessonContent> {
  LessonContentProvider._({
    required LessonContentFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'lessonContentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$lessonContentHash();

  @override
  String toString() {
    return r'lessonContentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<LessonContent> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LessonContent> create(Ref ref) {
    final argument = this.argument as String;
    return lessonContent(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LessonContentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$lessonContentHash() => r'c1b716c4df623a0f4831db90f1ac4a168f38e62b';

final class LessonContentFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<LessonContent>, String> {
  LessonContentFamily._()
    : super(
        retry: null,
        name: r'lessonContentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LessonContentProvider call(String lessonId) =>
      LessonContentProvider._(argument: lessonId, from: this);

  @override
  String toString() => r'lessonContentProvider';
}

@ProviderFor(courseAccessService)
final courseAccessServiceProvider = CourseAccessServiceProvider._();

final class CourseAccessServiceProvider
    extends
        $FunctionalProvider<
          CourseAccessService,
          CourseAccessService,
          CourseAccessService
        >
    with $Provider<CourseAccessService> {
  CourseAccessServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'courseAccessServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$courseAccessServiceHash();

  @$internal
  @override
  $ProviderElement<CourseAccessService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CourseAccessService create(Ref ref) {
    return courseAccessService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CourseAccessService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CourseAccessService>(value),
    );
  }
}

String _$courseAccessServiceHash() =>
    r'445e4e66e4dedb964ad6dafe8e4bfd1862a64e48';

@ProviderFor(UserSubscriptions)
final userSubscriptionsProvider = UserSubscriptionsProvider._();

final class UserSubscriptionsProvider
    extends $AsyncNotifierProvider<UserSubscriptions, Set<String>> {
  UserSubscriptionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userSubscriptionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userSubscriptionsHash();

  @$internal
  @override
  UserSubscriptions create() => UserSubscriptions();
}

String _$userSubscriptionsHash() => r'82d750aac65f369298c7d5572641e5b043ac0451';

abstract class _$UserSubscriptions extends $AsyncNotifier<Set<String>> {
  FutureOr<Set<String>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Set<String>>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Set<String>>, Set<String>>,
              AsyncValue<Set<String>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(PublicCourses)
final publicCoursesProvider = PublicCoursesProvider._();

final class PublicCoursesProvider
    extends $AsyncNotifierProvider<PublicCourses, PaginatedCoursesState> {
  PublicCoursesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'publicCoursesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$publicCoursesHash();

  @$internal
  @override
  PublicCourses create() => PublicCourses();
}

String _$publicCoursesHash() => r'2165ec1d1389f43e93f0a973090ed699cf634ecd';

abstract class _$PublicCourses extends $AsyncNotifier<PaginatedCoursesState> {
  FutureOr<PaginatedCoursesState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<PaginatedCoursesState>, PaginatedCoursesState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<PaginatedCoursesState>,
                PaginatedCoursesState
              >,
              AsyncValue<PaginatedCoursesState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(myCourseEnrollment)
final myCourseEnrollmentProvider = MyCourseEnrollmentFamily._();

final class MyCourseEnrollmentProvider
    extends
        $FunctionalProvider<
          AsyncValue<CourseEnrollment?>,
          CourseEnrollment?,
          FutureOr<CourseEnrollment?>
        >
    with
        $FutureModifier<CourseEnrollment?>,
        $FutureProvider<CourseEnrollment?> {
  MyCourseEnrollmentProvider._({
    required MyCourseEnrollmentFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'myCourseEnrollmentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$myCourseEnrollmentHash();

  @override
  String toString() {
    return r'myCourseEnrollmentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CourseEnrollment?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CourseEnrollment?> create(Ref ref) {
    final argument = this.argument as String;
    return myCourseEnrollment(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MyCourseEnrollmentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$myCourseEnrollmentHash() =>
    r'1ec6bfa7fa194223b8f50fe966cded42544c00fe';

final class MyCourseEnrollmentFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<CourseEnrollment?>, String> {
  MyCourseEnrollmentFamily._()
    : super(
        retry: null,
        name: r'myCourseEnrollmentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MyCourseEnrollmentProvider call(String courseId) =>
      MyCourseEnrollmentProvider._(argument: courseId, from: this);

  @override
  String toString() => r'myCourseEnrollmentProvider';
}

/// Aggregated progress for a single course (Global stats).
///
/// Uses `keepAlive: true` to persist across tab switches.
/// Invalidate explicitly after lesson completion via
/// `ref.invalidate(courseProgressProvider(courseId))`.

@ProviderFor(courseProgress)
final courseProgressProvider = CourseProgressFamily._();

/// Aggregated progress for a single course (Global stats).
///
/// Uses `keepAlive: true` to persist across tab switches.
/// Invalidate explicitly after lesson completion via
/// `ref.invalidate(courseProgressProvider(courseId))`.

final class CourseProgressProvider
    extends
        $FunctionalProvider<
          AsyncValue<CourseProgressSummary>,
          CourseProgressSummary,
          FutureOr<CourseProgressSummary>
        >
    with
        $FutureModifier<CourseProgressSummary>,
        $FutureProvider<CourseProgressSummary> {
  /// Aggregated progress for a single course (Global stats).
  ///
  /// Uses `keepAlive: true` to persist across tab switches.
  /// Invalidate explicitly after lesson completion via
  /// `ref.invalidate(courseProgressProvider(courseId))`.
  CourseProgressProvider._({
    required CourseProgressFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'courseProgressProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$courseProgressHash();

  @override
  String toString() {
    return r'courseProgressProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CourseProgressSummary> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CourseProgressSummary> create(Ref ref) {
    final argument = this.argument as String;
    return courseProgress(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CourseProgressProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$courseProgressHash() => r'8fc34a4d57a9c834831659418a942acea72edf21';

/// Aggregated progress for a single course (Global stats).
///
/// Uses `keepAlive: true` to persist across tab switches.
/// Invalidate explicitly after lesson completion via
/// `ref.invalidate(courseProgressProvider(courseId))`.

final class CourseProgressFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<CourseProgressSummary>, String> {
  CourseProgressFamily._()
    : super(
        retry: null,
        name: r'courseProgressProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Aggregated progress for a single course (Global stats).
  ///
  /// Uses `keepAlive: true` to persist across tab switches.
  /// Invalidate explicitly after lesson completion via
  /// `ref.invalidate(courseProgressProvider(courseId))`.

  CourseProgressProvider call(String courseId) =>
      CourseProgressProvider._(argument: courseId, from: this);

  @override
  String toString() => r'courseProgressProvider';
}

/// Device-local bookmarked course IDs for the current user.
///
/// Backed by [StorageService] (sqflite). No optimistic rollback —
/// local writes are fast enough to await directly.

@ProviderFor(BookmarkedCourses)
final bookmarkedCoursesProvider = BookmarkedCoursesProvider._();

/// Device-local bookmarked course IDs for the current user.
///
/// Backed by [StorageService] (sqflite). No optimistic rollback —
/// local writes are fast enough to await directly.
final class BookmarkedCoursesProvider
    extends $AsyncNotifierProvider<BookmarkedCourses, Set<String>> {
  /// Device-local bookmarked course IDs for the current user.
  ///
  /// Backed by [StorageService] (sqflite). No optimistic rollback —
  /// local writes are fast enough to await directly.
  BookmarkedCoursesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookmarkedCoursesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookmarkedCoursesHash();

  @$internal
  @override
  BookmarkedCourses create() => BookmarkedCourses();
}

String _$bookmarkedCoursesHash() => r'c1babdac38417471335f7e063bca2456b55b70a3';

/// Device-local bookmarked course IDs for the current user.
///
/// Backed by [StorageService] (sqflite). No optimistic rollback —
/// local writes are fast enough to await directly.

abstract class _$BookmarkedCourses extends $AsyncNotifier<Set<String>> {
  FutureOr<Set<String>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Set<String>>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Set<String>>, Set<String>>,
              AsyncValue<Set<String>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Fetches full course metadata for all currently bookmarked courses.
/// Re-evaluates automatically whenever the user adds or removes a bookmark.

@ProviderFor(savedCourses)
final savedCoursesProvider = SavedCoursesProvider._();

/// Fetches full course metadata for all currently bookmarked courses.
/// Re-evaluates automatically whenever the user adds or removes a bookmark.

final class SavedCoursesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Course>>,
          List<Course>,
          FutureOr<List<Course>>
        >
    with $FutureModifier<List<Course>>, $FutureProvider<List<Course>> {
  /// Fetches full course metadata for all currently bookmarked courses.
  /// Re-evaluates automatically whenever the user adds or removes a bookmark.
  SavedCoursesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedCoursesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedCoursesHash();

  @$internal
  @override
  $FutureProviderElement<List<Course>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Course>> create(Ref ref) {
    return savedCourses(ref);
  }
}

String _$savedCoursesHash() => r'cefabc186d9495bd51ee124f2a293b7ed7fdde42';
