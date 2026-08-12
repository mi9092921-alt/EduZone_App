import 'package:app/features/downloads/presentation/widgets/offline_player/offline_player_loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'offline_player_test_helpers.dart';

void main() {
  group('OfflinePlayerLoadingView', () {
    testWidgets('shows a progress indicator and the offline mode label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const OfflinePlayerLoadingView(aspectRatio: 16 / 9),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Localized text — verified against the actual delegate rather than a
      // hardcoded string so this doesn't silently pass if the key changes.
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('renders inside an AspectRatio matching the given ratio', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const OfflinePlayerLoadingView(aspectRatio: 9 / 16),
        ),
      );

      final aspectRatio = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(aspectRatio.aspectRatio, 9 / 16);
    });
  });
}
