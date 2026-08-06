import 'package:app/features/video_player/presentation/widgets/player4/player4_loading_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'player4_test_helpers.dart';

void main() {
  group('Player4LoadingOverlay', () {
    testWidgets('shows a progress indicator with the given spinner color', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const Player4LoadingOverlay(
            backgroundColor: Colors.black54,
            spinnerColor: Colors.red,
          ),
        ),
      );

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.color, Colors.red);
    });

    testWidgets('paints the given background color', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const Player4LoadingOverlay(
            backgroundColor: Colors.black54,
            spinnerColor: Colors.red,
          ),
        ),
      );

      final coloredBox = tester.widget<ColoredBox>(find.byType(ColoredBox));
      expect(coloredBox.color, Colors.black54);
    });
  });
}
