import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/design_system/design_system.dart';
import 'package:app/features/courses/presentation/widgets/course_about_tab_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'course_widget_test_helpers.dart';

void main() {
  testWidgets(
    'shows description, learning objectives, prerequisites and instructor '
    'for a fully-populated course',
    (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (context) => CourseAboutTabContent(
              course: tFullCourse,
              l10n: AppLocalizations.of(context)!,
              ds: AppColors.of(context),
            ),
          ),
        ),
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.text(tFullCourse.description!), findsOneWidget);
      expect(find.text('Build layouts'), findsOneWidget);
      expect(find.text('Manage state'), findsOneWidget);
      expect(find.text('Basic Dart knowledge'), findsOneWidget);
      expect(find.text(l10n.whatYouWillLearn), findsOneWidget);
      expect(find.text(l10n.coursePrerequisites), findsOneWidget);
      expect(find.text(l10n.instructorLabel), findsOneWidget);
    },
  );

  testWidgets(
    'hides the learning-objectives and prerequisites sections when the '
    'course has none',
    (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (context) => CourseAboutTabContent(
              course: tMinimalFreeCourse,
              l10n: AppLocalizations.of(context)!,
              ds: AppColors.of(context),
            ),
          ),
        ),
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.text(l10n.whatYouWillLearn), findsNothing);
      expect(find.text(l10n.coursePrerequisites), findsNothing);
      // The instructor section is unconditional and should still render.
      expect(find.text(l10n.instructorLabel), findsOneWidget);
    },
  );

  testWidgets('buildCourseAboutTabContent returns a flat, non-empty widget list', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestableWidget(
        Builder(
          builder: (context) {
            final children = buildCourseAboutTabContent(
              course: tFullCourse,
              l10n: AppLocalizations.of(context)!,
              ds: AppColors.of(context),
            );
            expect(children, isNotEmpty);
            return Column(children: children);
          },
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
