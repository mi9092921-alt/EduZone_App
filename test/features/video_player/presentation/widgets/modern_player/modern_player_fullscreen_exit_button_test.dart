import 'package:app/features/video_player/presentation/widgets/modern_player/modern_player_fullscreen_exit_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModernPlayerFullscreenExitButton', () {
    testWidgets('shows a fullscreen-exit icon with the given tooltip', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernPlayerFullscreenExitButton(
              tooltip: 'Exit fullscreen',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.fullscreen_exit_rounded), findsOneWidget);
      expect(find.byTooltip('Exit fullscreen'), findsOneWidget);
    });

    testWidgets('fires onPressed when tapped', (WidgetTester tester) async {
      var pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernPlayerFullscreenExitButton(
              tooltip: 'Exit fullscreen',
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(pressed, isTrue);
    });
  });
}
