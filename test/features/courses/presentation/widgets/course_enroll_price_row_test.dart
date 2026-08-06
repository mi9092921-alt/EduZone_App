import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/design_system/design_system.dart';
import 'package:app/features/courses/presentation/widgets/course_enroll_price_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'course_widget_test_helpers.dart';

void main() {
  testWidgets('shows the formatted price and an Enroll button for a paid course', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestableWidget(
        Builder(
          builder: (context) => CourseEnrollPriceRow(
            course: tFullCourse,
            l10n: AppLocalizations.of(context)!,
            ds: AppColors.of(context),
          ),
        ),
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text('\$49.99'), findsOneWidget);
    expect(find.text(l10n.enrollNow), findsOneWidget);
  });

  testWidgets('shows the "Free" label for a free course', (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        Builder(
          builder: (context) => CourseEnrollPriceRow(
            course: tMinimalFreeCourse,
            l10n: AppLocalizations.of(context)!,
            ds: AppColors.of(context),
          ),
        ),
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.freeLabel), findsOneWidget);
    expect(find.text(l10n.enrollNow), findsOneWidget);
  });
}
