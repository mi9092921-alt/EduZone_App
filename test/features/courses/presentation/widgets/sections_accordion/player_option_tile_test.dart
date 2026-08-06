import 'package:app/features/courses/presentation/widgets/sections_accordion/player_option_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sections_accordion_test_helpers.dart';

void main() {
  group('PlayerOptionTile', () {
    testWidgets('renders the title, subtitle, and icon', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          PlayerOptionTile(
            title: 'YouTube Player',
            subtitle: 'Standard player',
            icon: Icons.smart_display_rounded,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('YouTube Player'), findsOneWidget);
      expect(find.text('Standard player'), findsOneWidget);
      expect(find.byIcon(Icons.smart_display_rounded), findsOneWidget);
    });

    testWidgets('fires onTap when tapped', (WidgetTester tester) async {
      var tapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          PlayerOptionTile(
            title: 'YouTube Player',
            subtitle: 'Standard player',
            icon: Icons.smart_display_rounded,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
