import 'dart:async';

import 'package:app/core/error/failures.dart';
import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/courses/application/providers/courses_provider.dart';
import 'package:app/features/courses/domain/entities/course.dart';
import 'package:app/features/courses/domain/entities/course_enrollment.dart';
import 'package:app/features/courses/domain/repositories/courses_repository.dart';
import 'package:app/features/courses/presentation/screens/discover_screen.dart';
import 'package:app/shared/components/course_card.dart';
import 'package:app/shared/components/course_card/course_card_shimmers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockCoursesRepository extends Mock implements CoursesRepository {}

Course _course(String id, {required String title, String? category}) => Course(
      id: id,
      tenantId: 'tenant-1',
      title: title,
      status: 'published',
      category: category,
    );

Widget _wrap(CoursesRepository repository) {
  final router = GoRouter(
    initialLocation: '/discover',
    routes: [
      GoRoute(path: '/discover', builder: (_, _) => const DiscoverScreen()),
      GoRoute(
        path: '/courses/:id',
        builder: (_, state) =>
            Scaffold(body: Text('enrolled-${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/discover/course-preview/:id',
        builder: (_, state) =>
            Scaffold(body: Text('preview-${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/discover/saved',
        builder: (_, _) => const Scaffold(body: Text('saved-screen')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [coursesRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  late MockCoursesRepository repository;

  setUp(() {
    repository = MockCoursesRepository();
    // myCoursesProvider is watched by DiscoverScreen for enrollment-aware
    // tap routing; default to "not enrolled in anything".
    when(() => repository.getMyCourses()).thenAnswer((_) async => const Right([]));
  });

  group('DiscoverScreen — loading/empty/error', () {
    testWidgets('shows category-shaped shimmer placeholders while loading', (tester) async {
      when(() => repository.getPublicCourses())
          .thenAnswer((_) => Completer<Either<Failure, List<Course>>>().future);

      await tester.pumpWidget(_wrap(repository));
      await tester.pump();

      expect(find.byType(DiscoverCourseCardShimmer), findsNWidgets(6)); // 2 groups x 3
    });

    testWidgets('shows "no content" when the public course list is empty', (tester) async {
      when(() => repository.getPublicCourses())
          .thenAnswer((_) async => const Right([]));

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.noContentAvailable), findsOneWidget);
    });

    testWidgets(
        'shows the safe, localized error message (never a raw exception) '
        'when the public course fetch fails', (tester) async {
      when(() => repository.getPublicCourses())
          .thenAnswer((_) async => const Left(ServerFailure('pg error 23505')));

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.errorGeneric), findsOneWidget);
      expect(find.text('pg error 23505'), findsNothing);
    });
  });

  group('DiscoverScreen — category grouping', () {
    testWidgets(
        'groups by category, sorts non-general groups by course count '
        'descending, and always places "General" last', (tester) async {
      // Enlarge the test surface so all three category groups actually
      // lay out (SliverList only builds what's visible), instead of the
      // default small test viewport hiding the group we need to compare
      // vertical positions against.
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      when(() => repository.getPublicCourses()).thenAnswer(
        (_) async => Right([
          _course('c1', title: 'Flutter Basics', category: 'Flutter'),
          _course('c2', title: 'Flutter Advanced', category: 'Flutter'),
          _course('c3', title: 'Flutter State', category: 'flutter'), // same
          // category, different casing -> must merge into the same group
          _course('c4', title: 'Backend 101', category: 'Backend'),
          _course('c5', title: 'Uncategorized One'),
          _course('c6', title: 'Uncategorized Two', category: '   '), // blank
        ]),
      );

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text('Flutter'), findsOneWidget); // 3 courses -> largest group
      expect(find.text('Backend'), findsOneWidget); // 1 course
      expect(find.text(l10n.generalCategory), findsOneWidget); // 2 uncategorized

      final flutterY = tester.getTopLeft(find.text('Flutter')).dy;
      final backendY = tester.getTopLeft(find.text('Backend')).dy;
      final generalY = tester.getTopLeft(find.text(l10n.generalCategory)).dy;
      expect(flutterY, lessThan(backendY),
          reason: 'the 3-course group must be listed before the 1-course group');
      expect(backendY, lessThan(generalY),
          reason: 'General must always be the last group, regardless of its count');
    });

    testWidgets('omits the General group entirely when every course has a category',
        (tester) async {
      when(() => repository.getPublicCourses()).thenAnswer(
        (_) async => Right([_course('c1', title: 'Flutter Basics', category: 'Flutter')]),
      );

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.generalCategory), findsNothing);
    });
  });

  group('DiscoverScreen — search', () {
    testWidgets(
        'typing a query (after the debounce) filters to a flat list of '
        'matching courses, replacing the grouped carousels', (tester) async {
      when(() => repository.getPublicCourses()).thenAnswer(
        (_) async => Right([
          _course('c1', title: 'Flutter Basics', category: 'Flutter'),
          _course('c2', title: 'Backend 101', category: 'Backend'),
        ]),
      );

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.enterText(find.byType(TextFormField), 'flutter');
      // Debounce is 300ms; settle well past it.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Flutter Basics'), findsOneWidget);
      expect(find.text('Backend 101'), findsNothing);
      expect(find.text('Flutter'), findsNothing, reason: 'category headers are hidden while searching');
      expect(find.text(l10n.noContentAvailable), findsNothing);
    });

    testWidgets('a query matching nothing shows the "no content" state', (tester) async {
      when(() => repository.getPublicCourses()).thenAnswer(
        (_) async => Right([_course('c1', title: 'Flutter Basics', category: 'Flutter')]),
      );

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'nonexistent-xyz');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.noContentAvailable), findsOneWidget);
    });
  });

  group('DiscoverScreen — enrollment-aware navigation', () {
    testWidgets('tapping a course the user is enrolled in goes to /courses/:id', (tester) async {
      when(() => repository.getMyCourses()).thenAnswer(
        (_) async => const Right([
          CourseEnrollment(
            id: 'e1',
            userId: 'user-1',
            courseId: 'c1',
            tenantId: 'tenant-1',
          ),
        ]),
      );
      when(() => repository.getPublicCourses()).thenAnswer(
        (_) async => Right([_course('c1', title: 'Flutter Basics', category: 'Flutter')]),
      );

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Flutter Basics'));
      await tester.pumpAndSettle();

      expect(find.text('enrolled-c1'), findsOneWidget);
    });

    testWidgets('tapping a course the user is NOT enrolled in goes to the preview route',
        (tester) async {
      when(() => repository.getPublicCourses()).thenAnswer(
        (_) async => Right([_course('c1', title: 'Flutter Basics', category: 'Flutter')]),
      );

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Flutter Basics'));
      await tester.pumpAndSettle();

      expect(find.text('preview-c1'), findsOneWidget);
    });

    testWidgets('the bookmark icon action navigates to the saved-courses route', (tester) async {
      when(() => repository.getPublicCourses()).thenAnswer((_) async => const Right([]));

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.bookmark_border_rounded));
      await tester.pumpAndSettle();

      expect(find.text('saved-screen'), findsOneWidget);
    });
  });
}
