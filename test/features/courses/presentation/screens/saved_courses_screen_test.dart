import 'dart:async';

import 'package:app/core/error/failures.dart';
import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/courses/application/providers/courses_provider.dart';
import 'package:app/features/courses/domain/entities/course.dart';
import 'package:app/features/courses/domain/repositories/courses_repository.dart';
import 'package:app/features/courses/presentation/screens/saved_courses_screen.dart';
import 'package:app/shared/components/course_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockCoursesRepository extends Mock implements CoursesRepository {}

const _course = Course(
  id: 'course-1',
  tenantId: 'tenant-1',
  title: 'Flutter Mastery',
  status: 'published',
);

Widget _wrap(CoursesRepository repository) {
  final router = GoRouter(
    initialLocation: '/saved',
    routes: [
      GoRoute(
        path: '/saved',
        builder: (_, _) => const SavedCoursesScreen(),
      ),
      GoRoute(
        path: '/discover/course-preview/:id',
        builder: (_, state) =>
            Scaffold(body: Text('preview-${state.pathParameters['id']}')),
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
  });

  group('SavedCoursesScreen', () {
    testWidgets(
        'shows shimmer placeholders while bookmarks/course data are still '
        'resolving', (tester) async {
      when(() => repository.getBookmarkedCourseIds())
          .thenAnswer((_) => Completer<Either<Failure, Set<String>>>().future);

      await tester.pumpWidget(_wrap(repository));
      await tester.pump();

      expect(find.byType(DiscoverCourseCardShimmer), findsWidgets);
    });

    testWidgets('shows the empty state when there are no bookmarks', (tester) async {
      when(() => repository.getBookmarkedCourseIds())
          .thenAnswer((_) async => const Right(<String>{}));

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.savedCoursesEmptyMessage), findsOneWidget);
      verifyNever(() => repository.getCoursesByIds(any()));
    });

    testWidgets('renders a card for each bookmarked course', (tester) async {
      when(() => repository.getBookmarkedCourseIds())
          .thenAnswer((_) async => const Right({'course-1'}));
      when(() => repository.getCoursesByIds(['course-1']))
          .thenAnswer((_) async => const Right([_course]));

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      expect(find.text('Flutter Mastery'), findsOneWidget);
      expect(find.byType(DiscoverCourseCard), findsOneWidget);
    });

    testWidgets('tapping a saved course card navigates to its preview route', (tester) async {
      when(() => repository.getBookmarkedCourseIds())
          .thenAnswer((_) async => const Right({'course-1'}));
      when(() => repository.getCoursesByIds(['course-1']))
          .thenAnswer((_) async => const Right([_course]));

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Flutter Mastery'));
      await tester.pumpAndSettle();

      expect(find.text('preview-course-1'), findsOneWidget);
    });

    testWidgets('shows the failure banner and retry button when loading fails', (tester) async {
      when(() => repository.getBookmarkedCourseIds())
          .thenAnswer((_) async => const Left(ServerFailure('boom')));

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.failedToLoadCourses), findsOneWidget);
      expect(find.text(l10n.retryButton), findsOneWidget);
    });

    testWidgets('retrying after a failure re-invalidates and re-fetches bookmarks', (tester) async {
      when(() => repository.getBookmarkedCourseIds())
          .thenAnswer((_) async => const Left(ServerFailure('boom')));

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      when(() => repository.getBookmarkedCourseIds())
          .thenAnswer((_) async => const Right(<String>{}));

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.retryButton));
      await tester.pumpAndSettle();

      expect(find.text(l10n.savedCoursesEmptyMessage), findsOneWidget);
      verify(() => repository.getBookmarkedCourseIds()).called(greaterThanOrEqualTo(2));
    });
  });
}
