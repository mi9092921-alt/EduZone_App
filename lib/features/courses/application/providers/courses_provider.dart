import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/providers/storage_provider.dart';
import '../../../../shared/models/course.dart';
import '../../../../shared/models/lesson_content.dart';
import '../../data/datasources/courses_remote_ds_impl.dart';
import '../../data/repositories/courses_repo_impl.dart';
import '../../domain/entities/course_enrollment.dart';
import '../../domain/entities/course_progress_summary.dart';
import '../../domain/repositories/courses_repository.dart';
import '../../domain/services/course_access_service.dart';
import '../../domain/usecases/enroll_in_course.dart';
import '../../domain/usecases/get_bookmarked_course_ids.dart';
import '../../domain/usecases/get_course_details.dart';
import '../../domain/usecases/get_course_progress_summary.dart';
import '../../domain/usecases/get_courses_by_ids.dart';
import '../../domain/usecases/get_lesson_content.dart';
import '../../domain/usecases/get_my_course_enrollment.dart';
import '../../domain/usecases/get_my_courses.dart';
import '../../domain/usecases/get_public_courses.dart';
import '../../domain/usecases/get_user_subscribed_course_ids.dart';
import '../../domain/usecases/toggle_course_bookmark.dart';
import '../../domain/usecases/update_lesson_progress.dart';

part 'courses_provider.g.dart';

@riverpod
CoursesRemoteDataSourceImpl coursesRemoteDataSource(Ref ref) {
  return CoursesRemoteDataSourceImpl();
}

@riverpod
CoursesRepository coursesRepository(Ref ref) {
  final dataSource = ref.watch(coursesRemoteDataSourceProvider);
  final storage = ref.watch(storageServiceProvider);
  return CoursesRepositoryImpl(dataSource, storage);
}

@riverpod
GetMyCourses getMyCourses(Ref ref) {
  final repository = ref.watch(coursesRepositoryProvider);
  return GetMyCourses(repository);
}

@riverpod
GetCourseDetails getCourseDetails(Ref ref) {
  final repository = ref.watch(coursesRepositoryProvider);
  return GetCourseDetails(repository);
}

@riverpod
UpdateLessonProgress updateLessonProgress(Ref ref) {
  final repository = ref.watch(coursesRepositoryProvider);
  return UpdateLessonProgress(repository);
}

@riverpod
GetLessonContent getLessonContent(Ref ref) {
  final repository = ref.watch(coursesRepositoryProvider);
  return GetLessonContent(repository);
}

@riverpod
EnrollInCourse enrollInCourse(Ref ref) {
  final repository = ref.watch(coursesRepositoryProvider);
  return EnrollInCourse(repository);
}

@riverpod
GetPublicCourses getPublicCourses(Ref ref) {
  final repository = ref.watch(coursesRepositoryProvider);
  return GetPublicCourses(repository);
}

@riverpod
GetUserSubscribedCourseIds getUserSubscribedCourseIds(Ref ref) {
  final repository = ref.watch(coursesRepositoryProvider);
  return GetUserSubscribedCourseIds(repository);
}

@riverpod
GetMyCourseEnrollment getMyCourseEnrollment(Ref ref) {
  final repository = ref.watch(coursesRepositoryProvider);
  return GetMyCourseEnrollment(repository);
}

@riverpod
GetCourseProgressSummary getCourseProgressSummary(Ref ref) {
  final repository = ref.watch(coursesRepositoryProvider);
  return GetCourseProgressSummary(repository);
}

@riverpod
GetBookmarkedCourseIds getBookmarkedCourseIds(Ref ref) {
  final repository = ref.watch(coursesRepositoryProvider);
  return GetBookmarkedCourseIds(repository);
}

@riverpod
ToggleCourseBookmark toggleCourseBookmark(Ref ref) {
  final repository = ref.watch(coursesRepositoryProvider);
  return ToggleCourseBookmark(repository);
}

@riverpod
GetCoursesByIds getCoursesByIds(Ref ref) {
  final repository = ref.watch(coursesRepositoryProvider);
  return GetCoursesByIds(repository);
}

// -- State Providers --

@riverpod
Future<List<CourseEnrollment>> myCourses(Ref ref) async {
  final getMyCourses = ref.watch(getMyCoursesProvider);
  final result = await getMyCourses();

  return result.fold(
    (failure) => throw failure.toAppException(),
    (enrollments) => enrollments,
  );
}

/// Returns whether the current user is enrolled in the given [courseId].
///
/// Returns [AsyncValue] to preserve loading and error states — callers can
/// show skeletons or fallback UI instead of silently defaulting to `false`.
@riverpod
AsyncValue<bool> isEnrolled(Ref ref, String courseId) {
  return ref
      .watch(myCoursesProvider)
      .whenData(
        (enrollments) => enrollments.any((e) => e.courseId == courseId),
      );
}

@riverpod
Future<Course> courseDetails(Ref ref, String courseId) async {
  final getCourseDetails = ref.watch(getCourseDetailsProvider);
  final result = await getCourseDetails(courseId);
  return result.fold(
    (failure) => throw failure.toAppException(),
    (course) => course,
  );
}

@riverpod
Future<LessonContent> lessonContent(Ref ref, String lessonId) async {
  final getLessonContent = ref.watch(getLessonContentProvider);
  final result = await getLessonContent(lessonId);
  return result.fold(
    (failure) => throw failure.toAppException(),
    (content) => content,
  );
}

// -- Access & Discovery Providers --

@riverpod
CourseAccessService courseAccessService(Ref ref) {
  return CourseAccessService();
}

@riverpod
class UserSubscriptions extends _$UserSubscriptions {
  @override
  Future<Set<String>> build() async {
    final getUserSubscribedCourseIds = ref.watch(
      getUserSubscribedCourseIdsProvider,
    );
    final result = await getUserSubscribedCourseIds();
    return result.fold((_) => <String>{}, (ids) => ids);
  }

  // Enrollment is intentionally not triggered from the UI until payment is
  // integrated. Later, wire the confirmed payment flow to
  // enrollInCourseProvider.
  //
  // PRODUCT DECISION (audit 2026-09): enrollment is documented as OUT OF
  // RELEASE SCOPE — the EnrollActionButton intentionally surfaces
  // `enrollmentComingSoon` and `enrollInCourseProvider` stays unwired until
  // the payment flow ships. Do not wire it without a new product decision.
}

// Keep track of loaded pagination to prevent duplicates
class PaginatedCoursesState {
  final List<Course> items;
  final Set<String> loadedIds;
  final int page;
  final bool hasMore;
  // True only while an actual fetchNextPage() network request is in
  // flight. Distinct from `hasMore`, which just means "the last page was
  // full, so there might be another page" and stays true whether or not a
  // request is currently running. The pagination loading indicator in the
  // UI should key off this flag, not `hasMore`, or it would appear to spin
  // continuously any time more pages could exist, even while idle.
  final bool isLoadingMore;

  // True when the most recent fetchNextPage() request failed. The loaded
  // pages are KEPT in [items] — the UI shows an inline retry footer for
  // the next page instead of an AsyncError that would wipe the whole
  // browsed list and force a page-1 refetch on retry.
  final bool loadMoreError;

  PaginatedCoursesState({
    required this.items,
    required this.loadedIds,
    this.page = 1,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.loadMoreError = false,
  });

  PaginatedCoursesState copyWith({
    List<Course>? items,
    Set<String>? loadedIds,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    bool? loadMoreError,
  }) {
    return PaginatedCoursesState(
      items: items ?? this.items,
      loadedIds: loadedIds ?? this.loadedIds,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: loadMoreError ?? this.loadMoreError,
    );
  }
}

@riverpod
class PublicCourses extends _$PublicCourses {
  bool _isLoadingPage = false;
  int _buildGeneration = 0;
  int _pageRequestGeneration = 0;

  @override
  Future<PaginatedCoursesState> build() async {
    ++_buildGeneration;
    ++_pageRequestGeneration;
    _isLoadingPage = false;
    final getPublicCourses = ref.watch(getPublicCoursesProvider);
    final result = await getPublicCourses();
    return result.fold(
      (failure) => throw failure.toAppException(),
      (courses) => PaginatedCoursesState(
        items: courses,
        loadedIds: courses.map((c) => c.id).toSet(),
        hasMore: courses.length == 10,
      ),
    );
  }

  Future<void> fetchNextPage() async {
    if (_isLoadingPage) return;
    final currentState = state.value;
    if (currentState == null || !currentState.hasMore) return;

    final buildGeneration = _buildGeneration;
    final pageRequestGeneration = ++_pageRequestGeneration;
    _isLoadingPage = true;
    state = AsyncData(
      currentState.copyWith(isLoadingMore: true, loadMoreError: false),
    );
    try {
      final nextPage = currentState.page + 1;
      final getPublicCourses = ref.read(getPublicCoursesProvider);
      final result = await getPublicCourses(page: nextPage);

      if (!ref.mounted ||
          buildGeneration != _buildGeneration ||
          pageRequestGeneration != _pageRequestGeneration) {
        return;
      }

      result.fold(
        (failure) {
          // Keep the already-loaded pages and surface the failure as an
          // inline flag for the pagination footer instead of replacing the
          // whole state with AsyncError — previously a failed page 2+
          // wiped the browsed list and a retry refetched from page 1.
          state = AsyncData(
            currentState.copyWith(isLoadingMore: false, loadMoreError: true),
          );
        },
        (newCourses) {
          final Set<String> newIds = {...currentState.loadedIds};
          final List<Course> uniqueNewCourses = [];

          for (final course in newCourses) {
            if (!newIds.contains(course.id)) {
              newIds.add(course.id);
              uniqueNewCourses.add(course);
            }
          }

          state = AsyncData(
            PaginatedCoursesState(
              items: [...currentState.items, ...uniqueNewCourses],
              loadedIds: newIds,
              page: nextPage,
              hasMore: newCourses.length == 10,
            ),
          );
        },
      );
    } finally {
      _isLoadingPage = false;
    }
  }
}

@riverpod
Future<CourseEnrollment?> myCourseEnrollment(Ref ref, String courseId) async {
  final getMyCourseEnrollment = ref.watch(getMyCourseEnrollmentProvider);
  final result = await getMyCourseEnrollment(courseId);
  return result.fold(
    (failure) => throw failure.toAppException(),
    (enrollment) => enrollment,
  );
}

/// Aggregated progress for a single course (Global stats).
///
/// Uses `keepAlive: true` to persist across tab switches.
/// Invalidate explicitly after lesson completion via
/// `ref.invalidate(courseProgressProvider(courseId))`.
@Riverpod(keepAlive: true)
Future<CourseProgressSummary> courseProgress(Ref ref, String courseId) async {
  final getCourseProgressSummary = ref.watch(getCourseProgressSummaryProvider);
  final result = await getCourseProgressSummary(courseId);
  return result.fold(
    (failure) => throw failure.toAppException(),
    (summary) => summary,
  );
}

// ─── Bookmarks ──────────────────────────────────────────────────────────────────

/// Device-local bookmarked course IDs for the current user.
///
/// Backed by [StorageService] (sqflite). No optimistic rollback —
/// local writes are fast enough to await directly.
@Riverpod(keepAlive: true)
class BookmarkedCourses extends _$BookmarkedCourses {
  int _buildGeneration = 0;
  Future<void> _lastToggle = Future<void>.value();

  @override
  Future<Set<String>> build() async {
    ++_buildGeneration;
    final getBookmarkedCourseIds = ref.watch(getBookmarkedCourseIdsProvider);
    final result = await getBookmarkedCourseIds();
    return result.fold(
      (failure) => throw failure.toAppException(),
      (ids) => ids,
    );
  }

  /// Toggles the bookmark state for [courseId].
  ///
  /// Awaits the SQLite write, then refreshes state.
  Future<void> toggleBookmark(String courseId) async {
    final operation = _lastToggle.then<void>(
      (_) => _toggleBookmarkForCurrentGeneration(courseId),
    );
    _lastToggle = operation.catchError((Object _) {});
    await operation;
  }

  Future<void> _toggleBookmarkForCurrentGeneration(String courseId) async {
    final buildGeneration = _buildGeneration;
    final current = state.value ?? <String>{};
    final isBookmarked = current.contains(courseId);
    final toggleCourseBookmark = ref.read(toggleCourseBookmarkProvider);
    final result = await toggleCourseBookmark(
      courseId: courseId,
      isCurrentlyBookmarked: isBookmarked,
    );

    if (!ref.mounted || buildGeneration != _buildGeneration) return;

    result.fold(
      (failure) => Error.throwWithStackTrace(
        failure.toAppException(),
        StackTrace.current,
      ),
      (_) {
        state = AsyncData(
          isBookmarked
              ? ({...current}..remove(courseId))
              : {...current, courseId},
        );
      },
    );
  }
}

/// Fetches full course metadata for all currently bookmarked courses.
/// Re-evaluates automatically whenever the user adds or removes a bookmark.
@riverpod
Future<List<Course>> savedCourses(Ref ref) async {
  final bookmarkIds = await ref.watch(bookmarkedCoursesProvider.future);
  if (bookmarkIds.isEmpty) return const [];

  final getCoursesByIds = ref.watch(getCoursesByIdsProvider);
  final result = await getCoursesByIds(bookmarkIds.toList());
  return result.fold(
    (failure) => throw failure.toAppException(),
    (courses) => courses,
  );
}

// ─── Course ratings ──────────────────────────────────────────────────────────

/// The current user's own rating for a course (1–5), or null when they
/// haven't rated yet. Reads only the own row (course_ratings SELECT
/// policy) — other students' individual ratings are never exposed.
@riverpod
Future<int?> myCourseRating(Ref ref, String courseId) async {
  final repository = ref.watch(coursesRepositoryProvider);
  final result = await repository.getMyRating(courseId);
  return result.fold(
    (failure) => throw failure.toAppException(),
    (rating) => rating,
  );
}

/// Submits/updates the user's star rating through the repository and
/// refreshes every provider that renders the course-wide aggregate.
@riverpod
class CourseRatingSubmit extends _$CourseRatingSubmit {
  @override
  FutureOr<void> build() async {}

  Future<void> submit(String courseId, int rating) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final repository = ref.read(coursesRepositoryProvider);
      (await repository.rateCourse(courseId: courseId, rating: rating)).fold(
        (failure) => throw failure.toAppException(),
        (aggregate) => aggregate,
      );
    });
    if (result.hasError) {
      state = AsyncError(result.error!, result.stackTrace!);
      return;
    }
    state = const AsyncData(null);
    // The RPC already recomputed the aggregate server-side; re-read it
    // wherever it is displayed (cards, preview, details).
    ref.invalidate(myCourseRatingProvider(courseId));
    ref.invalidate(publicCoursesProvider);
    ref.invalidate(savedCoursesProvider);
  }
}

// ─── Session cleanup ─────────────────────────────────────────────────────────

/// Invalidates every user-scoped provider owned by the `courses` feature.
/// Called by [Auth.logout]. When you add a new user-scoped provider to this
/// file, add it here too.
///
/// [bookmarkedCoursesProvider] and [courseProgressProvider] are declared
/// `keepAlive: true` (see their doc comments) so, unlike the plain
/// `@riverpod` providers below them, they are NOT torn down automatically
/// when their last widget listener drops off. Without an explicit
/// invalidation here, either would keep serving the previous account's
/// bookmarks/progress out of memory to whichever account signs in next on
/// the same device/session — a direct violation of the project's
/// auth-cache-isolation requirement (EduZone_Authentication_Session_
/// Security_Architecture.md, "Auth Cache Isolation"): "After logout, User
/// A private cache must not leak to User B." `courseProgressProvider` is a
/// family; invalidating the family provider itself (no argument) clears
/// every cached courseId instance.
void invalidateCoursesProviders(Ref ref) {
  ref.invalidate(myCoursesProvider);
  ref.invalidate(coursesRemoteDataSourceProvider);
  ref.invalidate(bookmarkedCoursesProvider);
  ref.invalidate(courseProgressProvider);
  ref.invalidate(myCourseRatingProvider); // family: clears every courseId
}