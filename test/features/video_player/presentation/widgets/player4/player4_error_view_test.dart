import 'package:app/features/video_player/presentation/widgets/player4/player4_error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'player4_test_helpers.dart';

void main() {
  group('Player4ErrorView', () {
    testWidgets('shows the given error message and an error icon', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          Player4ErrorView(errorMessage: 'Server error', onRetry: () {}),
        ),
      );

      expect(find.text('Server error'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('fires onRetry when the retry button is tapped', (
      WidgetTester tester,
    ) async {
      var retried = false;

      await tester.pumpWidget(
        buildTestableWidget(
          Player4ErrorView(
            errorMessage: 'Server error',
            onRetry: () => retried = true,
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(retried, isTrue);
    });
  });
}
