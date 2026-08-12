import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/courses/presentation/widgets/sections_accordion/enrollment_required_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sections_accordion_test_helpers.dart';

void main() {
  group('showEnrollmentRequiredDialog', () {
    testWidgets('shows the enrollment-required title and message', (
      WidgetTester tester,
    ) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              return ElevatedButton(
                onPressed: () => showEnrollmentRequiredDialog(context),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.enrollmentRequired), findsOneWidget);
      expect(find.text(l10n.enrollToAccessLesson), findsOneWidget);
    });

    testWidgets('the close button dismisses the dialog', (
      WidgetTester tester,
    ) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              return ElevatedButton(
                onPressed: () => showEnrollmentRequiredDialog(context),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.closeButton));
      await tester.pumpAndSettle();

      expect(find.text(l10n.enrollmentRequired), findsNothing);
    });
  });
}
