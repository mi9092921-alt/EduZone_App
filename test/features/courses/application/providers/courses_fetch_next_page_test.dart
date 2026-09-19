import 'dart:async';

import 'package:app/core/error/failures.dart';
import 'package:app/features/courses/application/providers/courses_provider.dart';
import 'package:app/features/courses/domain/usecases/get_public_courses.dart';
import 'package:app/shared/models/course.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

/// Tests for [PublicCourses.fetchNextPage] against a mocked
/// [GetPublicCourses] usecase (the provider the notifier watches in
/// `build()` and reads in `fetchNextPage()`).
///
/// Pins the page-2 failure contract: a failed next page must KEEP the
/// already-loaded items and surface `loadMoreError` for the inline retry
/// footer, never replace the whole state with an [AsyncError] that would
/// wipe the browsed list and force a page-1 refetch.
class MockGetPublicCourses extends Mock implements GetPublicCourses {}

Course _course(String id) => Course(
      id: id,
      tenantId: 'tenant-1',
      title: 'Course $id',
      status: 'published',
    );

/// Builds page fixtures: page 1 is always full (10 courses), so
/// `hasMore` starts out true.
List<Course> _fullPage() =>
    [for (var i = 1; i <= 10; i++) _course('course-$i')];

void main() {
  late MockGetPublicCourses usecase;
  late ProviderContainer container;

  /// Canned results per requested page — the mock routes every
  /// `getPublicCourses(page: n, limit: m)` call through this map so each
  /// test only configures the pages it cares about.
  final pageResults = <int, Either<Failure, List<Course>>>{};
  final requestedPages = <int>[];

  setUp(() {
    usecase = MockGetPublicCourses();
    pageResults.clear();
    requestedPages.clear();
    when(
      () => usecase(page: any(named: 'page'), limit: any(named: 'limit')),
    ).thenAnswer((invocation) async {
      final page = invocation.namedArguments[#page] as int;
      requestedPages.add(page);
      return pageResults[page]!;
    });
    container = ProviderContainer(
      overrides: [
        getPublicCoursesProvider.overrideWithValue(usecase),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<PaginatedCoursesState> pumpWith(List<Course> initialPage) async {
    pageResults[1] = Right(initialPage);
    // Trigger build().
    final state = await container.read(publicCoursesProvider.future);
    return state;
  }

  group('PublicCourses.build', () {
    test('a full page (10 courses) leaves hasMore true at page 1',
        () async {
      final state = await pumpWith(_fullPage());

      expect(state.page, 1);
      expect(state.items, hasLength(10));
      expect(state.hasMore, isTrue);
      expect(state.isLoadingMore, isFalse);
      expect(state.loadMoreError, isFalse);
      expect(state.loadedIds, hasLength(10));
    });

    test('a short page marks hasMore false so no further page is requested',
        () async {
      final state = await pumpWith([_course('course-1')]);
      expect(state.hasMore, isFalse);

      await container.read(publicCoursesProvider.notifier).fetchNextPage();

      // Only the initial page-1 request must have happened.
      expect(requestedPages, [1]);
    });
  });

  group('PublicCourses.fetchNextPage', () {
    test('SUCCESS appends only unique new courses, advances the page, and '
        'clears the flags', () async {
      await pumpWith(_fullPage());
      pageResults[2] = Right([
        _course('course-10'), // duplicate already loaded from page 1
        _course('course-11'),
        _course('course-12'),
      ]);

      await container.read(publicCoursesProvider.notifier).fetchNextPage();

      final state = container.read(publicCoursesProvider).value!;
      expect(state.page, 2);
      expect(state.items, hasLength(12));
      expect(state.items.map((c) => c.id), containsAllInOrder([
        'course-9',
        'course-10',
        'course-11',
        'course-12',
      ]));
      expect(state.loadedIds, hasLength(12));
      // A short page-2 result means no further pages.
      expect(state.hasMore, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.loadMoreError, isFalse);
    });

    test('a full second page keeps hasMore true and the loaded ids unique',
        () async {
      await pumpWith(_fullPage());
      pageResults[2] = Right(
        [for (var i = 11; i <= 20; i++) _course('course-$i')],
      );

      await container.read(publicCoursesProvider.notifier).fetchNextPage();

      final state = container.read(publicCoursesProvider).value!;
      expect(state.page, 2);
      expect(state.items, hasLength(20));
      expect(state.loadedIds, hasLength(20));
      expect(state.hasMore, isTrue);
    });

    test('FAILURE keeps the loaded pages, keeps hasMore, and sets '
        'loadMoreError for the inline retry footer', () async {
      await pumpWith(_fullPage());
      pageResults[2] = const Left(ServerFailure('page 2 exploded'));

      await container.read(publicCoursesProvider.notifier).fetchNextPage();

      final state = container.read(publicCoursesProvider).value!;
      // The browsed list survives untouched — the failure must NOT surface
      // as an AsyncError that would wipe it and force a page-1 refetch.
      expect(state.items, hasLength(10));
      expect(state.page, 1);
      expect(state.hasMore, isTrue);
      expect(state.isLoadingMore, isFalse);
      expect(state.loadMoreError, isTrue);
      // Still on the same AsyncData instance — not an error state.
      expect(container.read(publicCoursesProvider).hasError, isFalse);
    });

    test('a retry after a loadMore failure succeeds and clears the flag',
        () async {
      await pumpWith(_fullPage());
      pageResults[2] = const Left(ServerFailure('page 2 exploded'));
      final notifier = container.read(publicCoursesProvider.notifier);

      await notifier.fetchNextPage();
      expect(
        container.read(publicCoursesProvider).value!.loadMoreError,
        isTrue,
      );

      // The operator retries once the backend recovers.
      pageResults[2] = Right([_course('course-11')]);
      await notifier.fetchNextPage();

      final state = container.read(publicCoursesProvider).value!;
      expect(state.loadMoreError, isFalse);
      expect(state.page, 2);
      expect(state.items, hasLength(11));
    });

    test('deduplicates a second fetchNextPage while one is in flight',
        () async {
      await pumpWith(_fullPage());
      final gate = Completer<Either<Failure, List<Course>>>();
      when(
        () => usecase(page: any(named: 'page'), limit: any(named: 'limit')),
      ).thenAnswer((invocation) async {
        final page = invocation.namedArguments[#page] as int;
        requestedPages.add(page);
        if (page == 2) return gate.future;
        return pageResults[page]!;
      });

      final notifier = container.read(publicCoursesProvider.notifier);
      final first = notifier.fetchNextPage();
      // The second tap while the first page-2 request is still in flight
      // must be a no-op, not a duplicate request.
      final second = notifier.fetchNextPage();
      gate.complete(Right([_course('course-11')]));
      await first;
      await second;

      expect(requestedPages.where((p) => p == 2), hasLength(1));
    });
  });
}
