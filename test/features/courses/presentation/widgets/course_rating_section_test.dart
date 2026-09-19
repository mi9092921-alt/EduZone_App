import 'package:app/core/feature_flags/feature_flag_keys.dart';
import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/design_system/design_system.dart';
import 'package:app/features/courses/presentation/widgets/course_rating_section.dart';
import 'package:app/shared/models/course.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'course_widget_test_helpers.dart';

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
}
