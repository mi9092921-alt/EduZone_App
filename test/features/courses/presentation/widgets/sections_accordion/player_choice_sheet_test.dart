import 'package:app/features/courses/presentation/widgets/sections_accordion/player_choice_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sections_accordion_test_helpers.dart';

void main() {
  group('showPlayerChoiceSheet', () {
    testWidgets('shows all three player options', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showPlayerChoiceSheet(context, onPlayerSelected: (_) {}),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('YouTube Player'), findsOneWidget);
      expect(find.text('Modern Player'), findsOneWidget);
      // The 3rd option's title comes from AppLocalizations (l10n.directPlayer),
      // so just confirm 3 tappable option rows exist rather than hardcoding
      // its localized text.
      expect(find.byType(InkWell), findsNWidgets(4));
    });

    testWidgets('tapping an option calls onPlayerSelected with the right key', (
      WidgetTester tester,
    ) async {
      String? selected;

      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showPlayerChoiceSheet(
                context,
                onPlayerSelected: (type) => selected = type,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Modern Player'));
      await tester.pump();

      expect(selected, 'modern');
    });
  });

  group('showPlayerChoiceSheet — kill switches', () {
    Future<void> pumpAndOpen(
      WidgetTester tester, {
      bool showYoutube = true,
      bool showModern = true,
      bool showDirectPlayer = true,
    }) async {
      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showPlayerChoiceSheet(
                context,
                onPlayerSelected: (_) {},
                showYoutube: showYoutube,
                showModern: showModern,
                showDirectPlayer: showDirectPlayer,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('hides the YouTube option when showYoutube is false', (
      tester,
    ) async {
      await pumpAndOpen(tester, showYoutube: false);

      expect(find.text('YouTube Player'), findsNothing);
      expect(find.text('Modern Player'), findsOneWidget);
    });

    testWidgets('hides the Modern option when showModern is false', (
      tester,
    ) async {
      await pumpAndOpen(tester, showModern: false);

      expect(find.text('Modern Player'), findsNothing);
      expect(find.text('YouTube Player'), findsOneWidget);
    });

    testWidgets(
        'does not open the sheet at all when every option is hidden', (
      tester,
    ) async {
      await pumpAndOpen(
        tester,
        showYoutube: false,
        showModern: false,
        showDirectPlayer: false,
      );

      expect(find.byType(PlayerChoiceSheet), findsNothing);
      expect(find.text('YouTube Player'), findsNothing);
      expect(find.text('Modern Player'), findsNothing);
    });
  });
}
