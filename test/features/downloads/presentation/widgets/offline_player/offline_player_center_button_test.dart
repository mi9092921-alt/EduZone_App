import 'package:app/features/downloads/presentation/widgets/offline_player/offline_player_center_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'offline_player_test_helpers.dart';

void main() {
  group('OfflinePlayerCenterButton', () {
    testWidgets('shows a play icon with the given tooltip', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          OfflinePlayerCenterButton(tooltip: 'Play', onPressed: () {}),
        ),
      );

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byTooltip('Play'), findsOneWidget);
    });

    testWidgets('fires onPressed when tapped', (WidgetTester tester) async {
      var pressed = false;

      await tester.pumpWidget(
        buildTestableWidget(
          OfflinePlayerCenterButton(
            tooltip: 'Play',
            onPressed: () => pressed = true,
          ),
        ),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(pressed, isTrue);
    });
  });
}
