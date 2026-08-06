import 'package:app/features/video_player/presentation/widgets/modern_player/modern_player_error_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModernPlayerErrorOverlay', () {
    testWidgets('shows the error code in the message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernPlayerErrorOverlay(errorCode: 150, onRetry: () {}),
          ),
        ),
      );

      expect(find.textContaining('150'), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
    });

    testWidgets('fires onRetry when the retry button is tapped', (
      WidgetTester tester,
    ) async {
      var retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernPlayerErrorOverlay(
              errorCode: 2,
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextButton));
      await tester.pump();

      expect(retried, isTrue);
    });
  });
}
