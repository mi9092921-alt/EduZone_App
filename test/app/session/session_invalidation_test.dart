import 'package:app/features/courses/application/providers/courses_provider.dart';
import 'package:app/features/courses/domain/entities/course_progress_summary.dart';
import 'package:app/features/courses/domain/repositories/courses_repository.dart';
import 'package:app/features/downloads/application/providers/downloads_provider.dart';
import 'package:app/features/downloads/domain/repositories/download_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class MockCoursesRepository extends Mock implements CoursesRepository {}

class MockDownloadRepository extends Mock implements DownloadRepository {}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// `invalidateCoursesProviders`/`invalidateDownloadsProviders` take a `Ref`,
/// which only exists inside a provider body — `ProviderContainer` does not
/// implement it directly. Running the call through a throwaway `Provider`
/// gives it a real `Ref` bound to [container] while still executing exactly
/// the same production invalidation code path exercised by
/// `Auth.logout`/`invalidateAllUserScopedProviders`.
void _runInvalidateCourses(ProviderContainer container) {
  container.read(Provider<void>((ref) => invalidateCoursesProviders(ref)));
}

void _runInvalidateDownloads(ProviderContainer container) {
  container.read(Provider<void>((ref) => invalidateDownloadsProviders(ref)));
}

/// Regression test for STATE-001 (Section 7 audit, 2026-08-17):
///
/// `bookmarkedCoursesProvider` / `courseProgressProvider` (courses feature)
/// and the whole `downloads` feature's `downloadsProvider` /
/// `totalStorageUsedProvider` are declared `keepAlive: true`, which means —
/// unlike every plain `@riverpod` (autoDispose) provider — they are never
/// torn down just because their last widget listener drops off. Before this
/// fix, none of the four were wired into
/// `invalidateAllUserScopedProviders`/the per-feature `invalidateXProviders`
/// helpers it calls, so they kept serving the previous account's bookmarks,
/// progress, and download list in memory to whichever account signed in
/// next on the same device/session, directly violating the project's
/// auth-cache-isolation requirement.
///
/// These tests assert the fix: invalidating each provider forces the next
/// read to hit the repository again rather than reusing the stale cached
/// value.
void main() {
  group('invalidateCoursesProviders — user-scoped keepAlive cache isolation', () {
    late MockCoursesRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = MockCoursesRepository();
      container = ProviderContainer(
        overrides: [coursesRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
    });

    test('re-fetches bookmarks from the repository after invalidation', () async {
      when(() => repository.getBookmarkedCourseIds())
          .thenAnswer((_) async => const Right({'course-a'}));

      // Keep the keepAlive provider alive with a listener, exactly like a
      // real widget's ref.watch would.
      container.listen(bookmarkedCoursesProvider, (_, _) {});
      final first = await container.read(bookmarkedCoursesProvider.future);
      expect(first, {'course-a'});
      verify(() => repository.getBookmarkedCourseIds()).called(1);

      // Simulate a different account's bookmarks being returned post-login.
      when(() => repository.getBookmarkedCourseIds())
          .thenAnswer((_) async => const Right({'course-b'}));

      _runInvalidateCourses(container);
      final second = await container.read(bookmarkedCoursesProvider.future);

      expect(
        second,
        {'course-b'},
        reason:
            'bookmarkedCoursesProvider must not keep serving the previous '
            "account's cached bookmark set after logout/invalidation",
      );
      verify(() => repository.getBookmarkedCourseIds()).called(1);
    });

    test('re-fetches course progress from the repository after invalidation', () async {
      const courseId = 'course-1';
      when(() => repository.getCourseProgressSummary(courseId)).thenAnswer(
        (_) async =>
            const Right(CourseProgressSummary(avgProgress: 10.0)),
      );

      container.listen(courseProgressProvider(courseId), (_, _) {});
      final first = await container.read(
        courseProgressProvider(courseId).future,
      );
      expect(first.avgProgress, 10.0);

      when(() => repository.getCourseProgressSummary(courseId)).thenAnswer(
        (_) async =>
            const Right(CourseProgressSummary(avgProgress: 90.0)),
      );

      // Invalidating the family provider with no argument must clear every
      // cached courseId instance.
      _runInvalidateCourses(container);
      final second = await container.read(
        courseProgressProvider(courseId).future,
      );

      expect(
        second.avgProgress,
        90.0,
        reason:
            'courseProgressProvider must not keep serving the previous '
            "account's cached progress after logout/invalidation",
      );
    });
  });

  group('invalidateDownloadsProviders — user-scoped keepAlive cache isolation', () {
    late MockDownloadRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = MockDownloadRepository();
      when(() => repository.changeStream)
          .thenAnswer((_) => const Stream.empty());
      container = ProviderContainer(
        overrides: [downloadRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
    });

    test('re-fetches the download list from the repository after invalidation', () async {
      when(() => repository.getDownloads())
          .thenAnswer((_) async => const Right([]));

      container.listen(downloadsProvider, (_, _) {});
      await container.read(downloadsProvider.future);
      verify(() => repository.getDownloads()).called(1);

      _runInvalidateDownloads(container);
      await container.read(downloadsProvider.future);

      verify(
        () => repository.getDownloads(),
      ).called(
        1,
      ); // one additional call triggered by the invalidation, not zero
    });

    test('re-fetches total storage used from the repository after invalidation', () async {
      when(() => repository.getDownloads())
          .thenAnswer((_) async => const Right([]));
      when(() => repository.getTotalStorageUsed())
          .thenAnswer((_) async => const Right(1024));

      container.listen(downloadsProvider, (_, _) {});
      container.listen(totalStorageUsedProvider, (_, _) {});
      await container.read(downloadsProvider.future);
      await container.read(totalStorageUsedProvider.future);
      verify(() => repository.getTotalStorageUsed()).called(1);

      _runInvalidateDownloads(container);
      await container.read(totalStorageUsedProvider.future);

      verify(
        () => repository.getTotalStorageUsed(),
      ).called(
        1,
      ); // one additional call triggered by the invalidation, not zero
    });
  });
}
