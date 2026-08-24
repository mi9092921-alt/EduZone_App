import 'dart:async';

import 'package:app/core/error/exceptions.dart';
import 'package:app/core/error/failures.dart';
import 'package:app/features/courses/application/providers/courses_provider.dart';
import 'package:app/features/courses/domain/entities/course.dart';
import 'package:app/features/courses/domain/entities/course_enrollment.dart';
import 'package:app/features/courses/domain/repositories/courses_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

// These tests target `courses_provider.dart` itself — the Riverpod wiring
// layer — which had no dedicated test file before this pass. Every usecase
// it wraps (GetMyCourses, GetPublicCourses, ToggleCourseBookmark, ...) is
// already unit-tested in isolation under domain/usecases/, and the
// keepAlive logout-isolation behavior of `bookmarkedCoursesProvider` /
// `courseProgressProvider` is already covered by
// test/app/session/session_invalidation_test.dart. What was still
// untested is the provider-layer logic that lives only in this file:
// `isEnrolled`'s AsyncValue derivation, `PublicCourses`'s pagination/dedup/
// in-flight-guard state machine, and `BookmarkedCourses`'s sequential
// toggle queue — all real, non-trivial Riverpod logic Section 7 requires
// to be audited for race conditions, not just thin repository wiring.

class MockCoursesRepository extends Mock implements CoursesRepository {}

Course _course(String id, {String title = 'Course'}) => Course(
      id: id,
      tenantId: 'tenant-1',
      title: title,
      status: 'published',
    );

CourseEnrollment _enrollment(String courseId) => CourseEnrollment(
      id: 'enrollment-$courseId',
      userId: 'user-1',
      courseId: courseId,
      tenantId: 'tenant-1',
    );

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late MockCoursesRepository repository;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    repository = MockCoursesRepository();
    container = ProviderContainer(
      overrides: [coursesRepositoryProvider.overrideWithValue(repository)],
      // Disable Riverpod 3.x's automatic retry so that provider error states
      // are stable and immediately observable in unit tests without
      // exponential-backoff timer interference.
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
  });

  group('myCoursesProvider', () {
    test('returns the enrollments from the repository on success', () async {
      when(() => repository.getMyCourses())
          .thenAnswer((_) async => Right([_enrollment('c1')]));

      final result = await container.read(myCoursesProvider.future);

      expect(result, [_enrollment('c1')]);
    });

    test(
        'surfaces a typed AppException (not the raw Failure) so the UI '
        'error layer can classify it (Section 14)', () async {
      when(() => repository.getMyCourses())
          .thenAnswer((_) async => const Left(NetworkFailure()));
      final sub = container.listen(myCoursesProvider, (_, _) {});
      addTearDown(sub.close);
      await _settle();

      final state = container.read(myCoursesProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<NoInternetException>());
    });
  });

  group('isEnrolledProvider', () {
    test('is true when the course id is present among enrollments', () async {
      when(() => repository.getMyCourses())
          .thenAnswer((_) async => Right([_enrollment('c1')]));
      container.listen(myCoursesProvider, (_, _) {});
      await container.read(myCoursesProvider.future);

      expect(container.read(isEnrolledProvider('c1')).value, true);
    });

    test('is false (not an error) when the course id is not enrolled', () async {
      when(() => repository.getMyCourses())
          .thenAnswer((_) async => const Right([]));
      container.listen(myCoursesProvider, (_, _) {});
      await container.read(myCoursesProvider.future);

      expect(container.read(isEnrolledProvider('missing')).value, false);
    });

    test(
        'preserves the loading state instead of defaulting to false while '
        'myCoursesProvider is still resolving', () async {
      final completer = Completer<Either<Failure, List<CourseEnrollment>>>();
      when(() => repository.getMyCourses())
          .thenAnswer((_) => completer.future);
      container.listen(myCoursesProvider, (_, _) {});

      expect(container.read(isEnrolledProvider('c1')).isLoading, true);

      completer.complete(const Right([]));
      await container.read(myCoursesProvider.future);
    });

    test(
        'preserves the error state instead of silently resolving to false '
        'when myCoursesProvider fails', () async {
      when(() => repository.getMyCourses())
          .thenAnswer((_) async => const Left(ServerFailure('boom')));
      final sub = container.listen(myCoursesProvider, (_, _) {});
      addTearDown(sub.close);
      await _settle();

      final state = container.read(isEnrolledProvider('c1'));
      expect(state.hasError, isTrue);
    });
  });

  group('courseDetailsProvider (family)', () {
    test('caches independently per courseId argument', () async {
      when(() => repository.getCourseDetails('c1'))
          .thenAnswer((_) async => Right(_course('c1', title: 'Course One')));
      when(() => repository.getCourseDetails('c2'))
          .thenAnswer((_) async => Right(_course('c2', title: 'Course Two')));

      final c1 = await container.read(courseDetailsProvider('c1').future);
      final c2 = await container.read(courseDetailsProvider('c2').future);

      expect(c1.title, 'Course One');
      expect(c2.title, 'Course Two');
      verify(() => repository.getCourseDetails('c1')).called(1);
      verify(() => repository.getCourseDetails('c2')).called(1);
    });
  });

  group('savedCoursesProvider', () {
    test(
        'does not call getCoursesByIds when there are no bookmarks '
        '(avoids an empty-list network round trip)', () async {
      when(() => repository.getBookmarkedCourseIds())
          .thenAnswer((_) async => const Right(<String>{}));
      container.listen(savedCoursesProvider, (_, _) {});

      final result = await container.read(savedCoursesProvider.future);

      expect(result, isEmpty);
      verifyNever(() => repository.getCoursesByIds(any()));
    });

    test('fetches full course objects for every bookmarked id', () async {
      when(() => repository.getBookmarkedCourseIds())
          .thenAnswer((_) async => const Right({'c1'}));
      when(() => repository.getCoursesByIds(['c1']))
          .thenAnswer((_) async => Right([_course('c1')]));
      container.listen(savedCoursesProvider, (_, _) {});

      final result = await container.read(savedCoursesProvider.future);

      expect(result.single.id, 'c1');
    });
  });

  group('BookmarkedCourses.toggleBookmark', () {
    test('adds the id to state after a successful bookmark call', () async {
      when(() => repository.getBookmarkedCourseIds())
          .thenAnswer((_) async => const Right(<String>{}));
      when(() => repository.bookmarkCourse('c1'))
          .thenAnswer((_) async => const Right(null));
      container.listen(bookmarkedCoursesProvider, (_, _) {});
      await container.read(bookmarkedCoursesProvider.future);

      await container.read(bookmarkedCoursesProvider.notifier).toggleBookmark('c1');

      expect(container.read(bookmarkedCoursesProvider).value, {'c1'});
    });

    test('removes the id from state after a successful unbookmark call', () async {
      when(() => repository.getBookmarkedCourseIds())
          .thenAnswer((_) async => const Right({'c1'}));
      when(() => repository.unbookmarkCourse('c1'))
          .thenAnswer((_) async => const Right(null));
      container.listen(bookmarkedCoursesProvider, (_, _) {});
      await container.read(bookmarkedCoursesProvider.future);

      await container.read(bookmarkedCoursesProvider.notifier).toggleBookmark('c1');

      expect(container.read(bookmarkedCoursesProvider).value, isEmpty);
    });

    test(
        'serializes concurrent toggles for different ids through the '
        'internal queue instead of racing them', () async {
      when(() => repository.getBookmarkedCourseIds())
          .thenAnswer((_) async => const Right(<String>{}));
      final order = <String>[];
      when(() => repository.bookmarkCourse('slow')).thenAnswer((_) async {
        order.add('slow-start');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        order.add('slow-end');
        return const Right(null);
      });
      when(() => repository.bookmarkCourse('fast')).thenAnswer((_) async {
        order.add('fast-start');
        order.add('fast-end');
        return const Right(null);
      });
      container.listen(bookmarkedCoursesProvider, (_, _) {});
      await container.read(bookmarkedCoursesProvider.future);

      final notifier = container.read(bookmarkedCoursesProvider.notifier);
      // 'slow' is launched first; if the queue (`_lastToggle`) didn't
      // serialize these, 'fast' (which resolves instantly once running)
      // would finish first and the two repository writes could interleave.
      final first = notifier.toggleBookmark('slow');
      final second = notifier.toggleBookmark('fast');
      await Future.wait([first, second]);

      expect(order, ['slow-start', 'slow-end', 'fast-start', 'fast-end']);
      expect(
        container.read(bookmarkedCoursesProvider).value,
        {'slow', 'fast'},
      );
    });

    test(
        'a failed toggle throws a typed AppException instead of silently '
        'leaving the UI thinking the bookmark changed', () async {
      when(() => repository.getBookmarkedCourseIds())
          .thenAnswer((_) async => const Right(<String>{}));
      when(() => repository.bookmarkCourse('c1'))
          .thenAnswer((_) async => const Left(ServerFailure('boom')));
      container.listen(bookmarkedCoursesProvider, (_, _) {});
      await container.read(bookmarkedCoursesProvider.future);

      await expectLater(
        container.read(bookmarkedCoursesProvider.notifier).toggleBookmark('c1'),
        throwsA(isA<ServerException>()),
      );
      // State must not have been optimistically/incorrectly mutated.
      expect(container.read(bookmarkedCoursesProvider).value, isEmpty);
    });
  });

  group('PublicCourses (publicCoursesProvider) pagination', () {
    test('build() sets hasMore true when a full page (10) comes back', () async {
      when(() => repository.getPublicCourses())
          .thenAnswer((_) async => Right(List.generate(10, (i) => _course('c$i'))));

      final state = await container.read(publicCoursesProvider.future);

      expect(state.items, hasLength(10));
      expect(state.page, 1);
      expect(state.hasMore, true);
    });

    test('build() sets hasMore false for a short (final) page', () async {
      when(() => repository.getPublicCourses())
          .thenAnswer((_) async => Right([_course('c1')]));

      final state = await container.read(publicCoursesProvider.future);

      expect(state.hasMore, false);
    });

    test(
        'fetchNextPage appends new courses, advances the page, and drops '
        'any id already loaded instead of duplicating it', () async {
      when(() => repository.getPublicCourses())
          .thenAnswer((_) async => Right(List.generate(10, (i) => _course('c$i'))));
      container.listen(publicCoursesProvider, (_, _) {});
      await container.read(publicCoursesProvider.future);

      when(() => repository.getPublicCourses(page: 2)).thenAnswer(
        (_) async => Right([
          _course('c9'), // already loaded on page 1 — must be deduped
          _course('cNew'),
        ]),
      );

      await container.read(publicCoursesProvider.notifier).fetchNextPage();
      final state = container.read(publicCoursesProvider).value!;

      expect(state.page, 2);
      expect(state.hasMore, false); // page 2 returned < 10 items
      expect(
        state.items.where((c) => c.id == 'c9'),
        hasLength(1),
        reason: 'a course id already present must not be duplicated',
      );
      expect(state.items.map((c) => c.id), contains('cNew'));
    });

    test(
        'a second fetchNextPage call while one is already in flight is a '
        'no-op (isLoadingPage guard), not a duplicate request', () async {
      when(() => repository.getPublicCourses())
          .thenAnswer((_) async => Right(List.generate(10, (i) => _course('c$i'))));
      container.listen(publicCoursesProvider, (_, _) {});
      await container.read(publicCoursesProvider.future);

      var callCount = 0;
      final completer = Completer<Either<Failure, List<Course>>>();
      when(() => repository.getPublicCourses(page: 2)).thenAnswer((_) {
        callCount++;
        return completer.future;
      });

      final notifier = container.read(publicCoursesProvider.notifier);
      final firstCall = notifier.fetchNextPage();
      final secondCall = notifier.fetchNextPage();
      completer.complete(Right([_course('c10')]));
      await Future.wait([firstCall, secondCall]);

      expect(callCount, 1);
    });

    test('fetchNextPage is a no-op once hasMore is false', () async {
      when(() => repository.getPublicCourses())
          .thenAnswer((_) async => Right([_course('c1')])); // short page -> hasMore=false
      container.listen(publicCoursesProvider, (_, _) {});
      await container.read(publicCoursesProvider.future);

      await container.read(publicCoursesProvider.notifier).fetchNextPage();

      verify(() => repository.getPublicCourses()).called(1);
    });
  });
}
