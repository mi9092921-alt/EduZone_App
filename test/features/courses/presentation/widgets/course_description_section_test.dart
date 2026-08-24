import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/design_system/design_system.dart';
import 'package:app/features/courses/presentation/widgets/course_description_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'course_widget_test_helpers.dart';

Widget _build(String description) => buildTestableWidget(
      Builder(
        builder: (context) => CourseDescriptionSection(
          description: description,
          l10n: AppLocalizations.of(context)!,
          ds: AppColors.of(context),
        ),
      ),
    );

void main() {
  group('CourseDescriptionSection', () {
    testWidgets('renders nothing for an empty description', (tester) async {
      await tester.pumpWidget(_build(''));

      expect(find.byType(CourseDescriptionSection), findsOneWidget);
      expect(find.text(''), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders nothing for a whitespace-only description', (tester) async {
      await tester.pumpWidget(_build('   \n  '));

      expect(find.byType(Text), findsNothing);
    });

    testWidgets(
        'shows the section label and the description text for a short '
        'description, with no "show more" toggle', (tester) async {
      await tester.pumpWidget(_build('A short course description.'));

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.text(l10n.courseDescriptionLabel), findsOneWidget);
      expect(find.text('A short course description.'), findsOneWidget);
      expect(find.text(l10n.showMore), findsNothing);
    });

    testWidgets(
        'a long description shows a "show more" toggle that expands to '
        '"show less" on tap', (tester) async {
      final longText = 'This is a very long course description. ' * 6;
      await tester.pumpWidget(_build(longText));

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.showMore), findsOneWidget);

      await tester.tap(find.text(l10n.showMore));
      await tester.pumpAndSettle();

      expect(find.text(l10n.showLess), findsOneWidget);
      expect(find.text(l10n.showMore), findsNothing);
    });
  });
}
