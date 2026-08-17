import 'package:app/features/courses/application/providers/courses_provider.dart';
import 'package:app/features/courses/domain/entities/course_progress_summary.dart';
import 'package:app/features/courses/domain/repositories/courses_repository.dart';
import 'package:app/features/downloads/application/providers/downloads_provider.dart';
import 'package:app/features/downloads/domain/repositories/download_repository.dart';
import 'package:app/features/video_player/application/providers/video_provider.dart';
import 'package:app/features/video_player/domain/entities/lesson_progress_sync_item.dart';
import 'package:app/features/video_player/domain/repositories/video_player_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class MockCoursesRepository extends Mock implements CoursesRepository {}

class MockDownloadRepository extends Mock implements DownloadRepository {}

class MockVideoPlayerRepository extends Mock implements VideoPlayerRepository {}

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

void _runInvalidateVideoProgress(ProviderContainer container) {
  container.read(
    Provider<void>((ref) => invalidateVideoProgressProviders(ref)),
  );
}

/// Regression test for STATE-001 and STATE-002 (Section 7 audit,
/// 2026-08-17/18):
///
/// `bookmarkedCoursesProvider` / `courseProgressProvider` (courses feature),
/// the whole `downloads` feature's `downloadsProvider` /
/// `totalStorageUsedProvider`, and the `video_player` feature's
/// `videoProgressProvider` are all declared/kept `keepAlive: true`, which
/// means — unlike every plain `@riverpod` (autoDispose) provider — they are
/// never torn down just because their last widget listener drops off.
/// Before these fixes, none of them were wired into
/// `invalidateAllUserScopedProviders`/the per-feature `invalidateXProviders`
/// helpers it calls, so they kept serving the previous account's bookmarks,
/// course progress, download list, and video watch progress in memory to
/// whichever account signed in next on the same device/session, directly
/// violating the project's auth-cache-isolation requirement.
///
/// These tests assert the fix: invalidating each provider forces the next
/// read to either hit the repository again or reset to a fresh default
/// state, rather than reusing the previous account's cached value.
void main() {
  setUpAll(() {
    // Needed by mocktail for `any()` matchers when the argument type isn't
    // a primitive (mirrors test/features/video_player/.../video_provider_test.dart).
    registerFallbackValue(<LessonProgressSyncItem>[]);
  });

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

  group(
    'invalidateVideoProgressProviders — user-scoped keepAlive cache isolation (STATE-002)',
    () {
      const courseId = 'course-1';
      const lessonId = 'lesson-1';

      late MockVideoPlayerRepository repository;
      late ProviderContainer container;

      setUp(() {
        repository = MockVideoPlayerRepository();
        when(
          () => repository.syncProgressBatch(any()),
        ).thenAnswer((_) async => const Right(null));
        when(
          () => repository.logActivity(
            eventType: any(named: 'eventType'),
            metadata: any(named: 'metadata'),
          ),
        ).thenAnswer((_) async {});
        container = ProviderContainer(
          overrides: [
            videoPlayerRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);
      });

      test(
        'resets to a fresh VideoState instead of leaking the previous '
        "account's in-memory watch progress",
        () async {
          container.listen(videoProgressProvider(courseId, lessonId), (_, _) {});

          // Simulate the first account watching partway through the lesson.
          container
              .read(videoProgressProvider(courseId, lessonId).notifier)
              .updateProgress(42.0, 120, courseId, lessonId);
          expect(
            container.read(videoProgressProvider(courseId, lessonId)).progressPct,
            42.0,
          );

          _runInvalidateVideoProgress(container);

          // A second account opening the exact same lesson afterwards must
          // see a fresh state, not the first account's leftover progress.
          container.listen(videoProgressProvider(courseId, lessonId), (_, _) {});
          final rebuilt = container.read(
            videoProgressProvider(courseId, lessonId),
          );

          expect(
            rebuilt.progressPct,
            0.0,
            reason:
                'videoProgressProvider must not keep serving the previous '
                "account's cached watch progress after logout/invalidation",
          );
          expect(rebuilt.watchTimeSec, 0);
          expect(rebuilt.isCompleted, false);
        },
      );

      test(
        'flushes pending progress to the repository as part of invalidation, '
        'not silently dropping it',
        () async {
          container.listen(videoProgressProvider(courseId, lessonId), (_, _) {});
          container
              .read(videoProgressProvider(courseId, lessonId).notifier)
              .updateProgress(55.0, 200, courseId, lessonId);

          _runInvalidateVideoProgress(container);
          // The final sync is queued via a debounced/batching engine; give
          // its microtask/flush chain a turn to run.
          await Future<void>.delayed(Duration.zero);

          verify(() => repository.syncProgressBatch(any())).called(1);
        },
      );
    },
  );
}
