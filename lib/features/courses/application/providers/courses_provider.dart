import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers/storage_provider.dart';
import '../../data/datasources/courses_remote_ds_impl.dart';
import '../../data/repositories/courses_repo_impl.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/course_enrollment.dart';
import '../../domain/entities/course_progress_summary.dart';
import '../../domain/entities/lesson_content.dart';
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
    (failure) => throw Exception(failure.message),
    (enrollments) => enrollments,
  );
}

/// Returns whether the current user is enrolled in the given [courseId].
///
/// Returns [AsyncValue] to preserve loading and error states — callers can
/// show skeletons or fallback UI instead of silently defaulting to `false`.
@riverpod
AsyncValue<bool> isEnrolled(Ref ref, String courseId) {
  return ref.watch(myCoursesProvider).whenData(
    (enrollments) => enrollments.any((e) => e.courseId == courseId),
  );
}

@riverpod
Future<Course> courseDetails(Ref ref, String courseId) async {
  final getCourseDetails = ref.watch(getCourseDetailsProvider);
  final result = await getCourseDetails(courseId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (course) => course,
  );
}

@riverpod
Future<LessonContent> lessonContent(Ref ref, String lessonId) async {
  final getLessonContent = ref.watch(getLessonContentProvider);
  final result = await getLessonContent(lessonId);
  return result.fold(
    (failure) => throw Exception(failure.message),
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

  // Enrollment is intentionally not triggered from the UI until payment is integrated.
  // Later, wire the confirmed payment flow to enrollInCourseProvider.
}

// Keep track of loaded pagination to prevent duplicates
class PaginatedCoursesState {
  final List<Course> items;
  final Set<String> loadedIds;
  final int page;
  final bool hasMore;

  PaginatedCoursesState({
    required this.items,
    required this.loadedIds,
    this.page = 1,
    this.hasMore = true,
  });
}

@riverpod
class PublicCourses extends _$PublicCourses {
  bool _isLoadingPage = false;

  @override
  Future<PaginatedCoursesState> build() async {
    final getPublicCourses = ref.watch(getPublicCoursesProvider);
    final result = await getPublicCourses();
    return result.fold(
      (failure) => throw Exception(failure.message),
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

    _isLoadingPage = true;
    try {
      final nextPage = currentState.page + 1;
      final getPublicCourses = ref.read(getPublicCoursesProvider);
      final result = await getPublicCourses(page: nextPage);

      result.fold(
        (failure) {}, // handle error appropriately (e.g. snackbar)
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
    (failure) => throw Exception(failure.message),
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
    (failure) => throw Exception(failure.message),
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
  @override
  Future<Set<String>> build() async {
    final getBookmarkedCourseIds = ref.watch(getBookmarkedCourseIdsProvider);
    final result = await getBookmarkedCourseIds();
    return result.fold((_) => <String>{}, (ids) => ids);
  }

  /// Toggles the bookmark state for [courseId].
  ///
  /// Awaits the SQLite write, then refreshes state.
  Future<void> toggleBookmark(String courseId) async {
    final current = state.value ?? <String>{};
    final isBookmarked = current.contains(courseId);
    final toggleCourseBookmark = ref.read(toggleCourseBookmarkProvider);
    await toggleCourseBookmark(
      courseId: courseId,
      isCurrentlyBookmarked: isBookmarked,
    );
    state = AsyncData(
      isBookmarked
          ? ({...current}..remove(courseId))
          : {...current, courseId},
    );
  }
}

/// Fetches full course metadata for all currently bookmarked courses.
/// Re-evaluates automatically whenever the user adds or removes a bookmark.
@riverpod
Future<List<Course>> savedCourses(Ref ref) async {
  final bookmarksAsync = ref.watch(bookmarkedCoursesProvider);
  final bookmarkIds = bookmarksAsync.asData?.value ?? <String>{};

  if (bookmarkIds.isEmpty) return const [];

  final getCoursesByIds = ref.watch(getCoursesByIdsProvider);
  final result = await getCoursesByIds(bookmarkIds.toList());
  return result.fold(
    (failure) => throw Exception(failure.message),
    (courses) => courses,
  );
}

// ─── Session cleanup ─────────────────────────────────────────────────────────

/// Invalidates every user-scoped provider owned by the `courses` feature.
/// Called by [Auth.logout]. When you add a new user-scoped provider to this
/// file, add it here too.
void invalidateCoursesProviders(Ref ref) {
  ref.invalidate(myCoursesProvider);
  ref.invalidate(coursesRemoteDataSourceProvider);
}
