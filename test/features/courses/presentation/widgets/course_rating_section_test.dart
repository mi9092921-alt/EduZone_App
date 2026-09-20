import 'dart:async';

import 'package:app/core/error/failures.dart';
import 'package:app/core/feature_flags/feature_flag_keys.dart';
import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/design_system/design_system.dart';
import 'package:app/features/courses/application/providers/courses_provider.dart';
import 'package:app/features/courses/domain/repositories/courses_repository.dart';
import 'package:app/features/courses/presentation/widgets/course_rating_section.dart';
import 'package:app/shared/models/course.dart';
import 'package:app/shared/models/course_rating.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'course_widget_test_helpers.dart';

class _MockCoursesRepository extends Mock implements CoursesRepository {}

void main() {
  // A course carrying a live aggregate; the input's visibility is decided
  // by the per-test provider overrides, never by this fixture.
  const ratedCourse = Course(
    id: 'course-1',
    tenantId: 'tenant-1',
    title: 'Flutter for Beginners',
    status: 'published',
    rating: 4.5,
    ratingCount: 12,
  );

  Widget buildSection() => Builder(
        builder: (context) => CourseRatingSection(
          course: ratedCourse,
          l10n: AppLocalizations.of(context)!,
          ds: AppColors.of(context),
        ),
      );

  group('CourseRatingSection', () {
    testWidgets('shows the aggregate average and count', (tester) async {
      await tester.pumpWidget(buildTestableWidget(buildSection()));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text('4.5'), findsOneWidget);
      expect(find.text(l10n.ratingsCountLabel(12)), findsOneWidget);
    });

    testWidgets('shows an em-dash and zero count when unrated', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (context) => CourseRatingSection(
              course: ratedCourse.copyWith(rating: null, ratingCount: 0),
              l10n: AppLocalizations.of(context)!,
              ds: AppColors.of(context),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text('—'), findsOneWidget);
      expect(find.text(l10n.ratingsCountLabel(0)), findsOneWidget);
    });

    testWidgets('hides the star input and explains why when not enrolled', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestableWidget(buildSection()));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.byKey(const ValueKey('rating_star_1')), findsNothing);
      expect(find.text(l10n.ratingNotEnrolled), findsOneWidget);
    });

    testWidgets('renders the tappable star input when enrolled', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(buildSection(), enrolled: true, myRating: 4),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // Current own rating (4) pre-fills the row: stars 1-4 filled.
      // (Stars render through AppIconButton — icon is an IconData there.)
      final filled = tester.widget<AppIconButton>(
        find.byKey(const ValueKey('rating_star_4')),
      );
      expect(filled.icon, Icons.star_rounded);
      final outline = tester.widget<AppIconButton>(
        find.byKey(const ValueKey('rating_star_5')),
      );
      expect(outline.icon, Icons.star_outline_rounded);
      // Enrolled: the not-enrolled hint must not render.
      expect(find.text(l10n.ratingNotEnrolled), findsNothing);
    });

    testWidgets('star input disappears when the kill switch is off', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          buildSection(),
          enrolled: true,
          flagValues: {FeatureFlagKey.courseRating: false},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('rating_star_1')), findsNothing);
      // Aggregate display is NOT gated by the flag — only the input is.
      expect(find.text('4.5'), findsOneWidget);
    });
  });

  group('CourseRatingSection — optimistic star input', () {
    // The section is rendered at the bottom of a scrollable; bring the star
    // row into view before tapping.
    Future<void> pumpAndReveal(WidgetTester tester, Widget widget) async {
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('rating_star_5')));
      await tester.pumpAndSettle();
    }

    AppIconButton star(WidgetTester tester, int star) => tester.widget<
        AppIconButton>(find.byKey(ValueKey('rating_star_$star')));

    testWidgets(
        'lights the tapped star immediately, while the submit round-trip '
        'is still in flight', (tester) async {
      final repo = _MockCoursesRepository();
      // Never completes: the provider value stays 4 for the whole test, so
      // any fill on star 5 can only come from the optimistic state.
      final neverCompletes =
          Completer<Either<Failure, CourseRatingAggregate>>();
      when(() => repo.rateCourse(courseId: 'course-1', rating: 5))
          .thenAnswer((_) => neverCompletes.future);

      await pumpAndReveal(
        tester,
        buildTestableWidget(
          buildSection(),
          enrolled: true,
          myRating: 4,
          overrides: [coursesRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      expect(star(tester, 5).icon, Icons.star_outline_rounded);
      await tester.tap(find.byKey(const ValueKey('rating_star_5')));
      await tester.pump();

      expect(star(tester, 5).icon, Icons.star_rounded);
      expect(star(tester, 4).icon, Icons.star_rounded);
    });

    testWidgets('reverts the optimistic star when the submission fails', (
      tester,
    ) async {
      final repo = _MockCoursesRepository();
      // Held open so the optimistic fill can be observed while the submit is
      // in flight, then failed to verify the revert.
      final inFlight = Completer<Either<Failure, CourseRatingAggregate>>();
      when(() => repo.rateCourse(courseId: 'course-1', rating: 5))
          .thenAnswer((_) => inFlight.future);

      await pumpAndReveal(
        tester,
        buildTestableWidget(
          buildSection(),
          enrolled: true,
          myRating: 4,
          overrides: [coursesRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      await tester.tap(find.byKey(const ValueKey('rating_star_5')));
      await tester.pump();
      expect(star(tester, 5).icon, Icons.star_rounded);

      inFlight.complete(const Left(ServerFailure('rate rejected')));
      await tester.pumpAndSettle();
      expect(
        star(tester, 5).icon,
        Icons.star_outline_rounded,
        reason: 'a failed submit must not leave the star filled',
      );
      expect(star(tester, 4).icon, Icons.star_rounded);
    });

    testWidgets('a successful submit keeps the new star filled', (
      tester,
    ) async {
      final repo = _MockCoursesRepository();
      when(() => repo.rateCourse(courseId: 'course-1', rating: 5)).thenAnswer(
        (_) async => const Right(
          CourseRatingAggregate(courseId: 'course-1', rating: 4.6, ratingCount: 13),
        ),
      );
      // Note: the helper overrides myCourseRatingProvider itself, so the
      // post-submit invalidation re-reads the override, not the repository.

      await pumpAndReveal(
        tester,
        buildTestableWidget(
          buildSection(),
          enrolled: true,
          myRating: 4,
          overrides: [coursesRepositoryProvider.overrideWithValue(repo)],
        ),
      );

      await tester.tap(find.byKey(const ValueKey('rating_star_5')));
      await tester.pump();
      expect(star(tester, 5).icon, Icons.star_rounded);

      await tester.pumpAndSettle();
      expect(star(tester, 5).icon, Icons.star_rounded);
      verify(() => repo.rateCourse(courseId: 'course-1', rating: 5)).called(1);

      // Drain the success-toast's 3s auto-dismiss Timer so the test does not
      // end with a pending timer.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  });
}
