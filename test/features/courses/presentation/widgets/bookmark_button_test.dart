import 'dart:async';

import 'package:app/core/error/failures.dart';
import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/courses/application/providers/courses_provider.dart';
import 'package:app/features/courses/domain/repositories/courses_repository.dart';
import 'package:app/features/courses/presentation/widgets/bookmark_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockCoursesRepository extends Mock implements CoursesRepository {}

Widget _wrap(CoursesRepository repository, {String courseId = 'course-1'}) {
  return ProviderScope(
    overrides: [coursesRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: BookmarkButton(courseId: courseId)),
    ),
  );
}

void main() {
  late MockCoursesRepository repository;

  setUp(() {
    repository = MockCoursesRepository();
  });

  group('BookmarkButton', () {
    testWidgets('shows the outline icon and "add" label when not bookmarked', (tester) async {
      when(() => repository.getBookmarkedCourseIds())
          .thenAnswer((_) async => const Right(<String>{}));

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();
      final handle = tester.ensureSemantics();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_rounded), findsNothing);
      expect(
        tester.getSemantics(find.byType(BookmarkButton)).label,
        l10n.bookmarkAdd,
      );
      handle.dispose();
    });

    testWidgets('shows the filled icon and "remove" label when already bookmarked', (tester) async {
      when(() => repository.getBookmarkedCourseIds())
          .thenAnswer((_) async => const Right({'course-1'}));

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();
      final handle = tester.ensureSemantics();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(BookmarkButton)).label,
        l10n.bookmarkRemove,
      );
      handle.dispose();
    });

    testWidgets('tapping toggles the bookmark through the repository', (tester) async {
      when(() => repository.getBookmarkedCourseIds())
          .thenAnswer((_) async => const Right(<String>{}));
      when(() => repository.bookmarkCourse('course-1'))
          .thenAnswer((_) async => const Right(null));

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BookmarkButton));
      await tester.pumpAndSettle();

      verify(() => repository.bookmarkCourse('course-1')).called(1);
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    });

    testWidgets(
        'a second tap while a toggle is still in flight is ignored '
        '(_isToggling guard), not a duplicate repository call', (tester) async {
      when(() => repository.getBookmarkedCourseIds())
          .thenAnswer((_) async => const Right(<String>{}));
      final completer = Completer<Either<Failure, void>>();
      when(() => repository.bookmarkCourse('course-1'))
          .thenAnswer((_) => completer.future);

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BookmarkButton));
      await tester.pump();
      await tester.tap(find.byType(BookmarkButton)); // ignored while in flight
      await tester.pump();

      completer.complete(const Right(null));
      await tester.pumpAndSettle();

      verify(() => repository.bookmarkCourse('course-1')).called(1);
    });

    testWidgets(
        'a failed toggle shows the localized error snackbar instead of '
        'silently changing (or not changing) the icon', (tester) async {
      when(() => repository.getBookmarkedCourseIds())
          .thenAnswer((_) async => const Right(<String>{}));
      when(() => repository.bookmarkCourse('course-1'))
          .thenAnswer((_) async => const Left(ServerFailure('boom')));

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BookmarkButton));
      await tester.pump(); // let the toggle future settle
      await tester.pumpAndSettle(); // let the SnackBar animate in

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.bookmarkFailed), findsOneWidget);
      expect(
        find.byIcon(Icons.bookmark_border_rounded),
        findsOneWidget,
        reason: 'a failed toggle must not leave the icon showing '
            'bookmarked',
      );
    });
  });
}
