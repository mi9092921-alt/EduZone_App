import 'package:app/features/downloads/presentation/widgets/offline_player/offline_player_error_view.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'offline_player_test_helpers.dart';

void main() {
  group('OfflinePlayerErrorView', () {
    testWidgets('shows an error icon and a retry button that fires onRetry', (
      WidgetTester tester,
    ) async {
      var retried = false;

      await tester.pumpWidget(
        buildTestableWidget(
          OfflinePlayerErrorView(
            aspectRatio: 16 / 9,
            errorMessage: 'Some failure',
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);

      await tester.tap(find.byType(TextButton));
      await tester.pump();

      expect(retried, isTrue);
    });

    testWidgets('shows the raw error message only in debug builds', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          OfflinePlayerErrorView(
            aspectRatio: 16 / 9,
            errorMessage: 'Decryption failed: bad tag',
            onRetry: () {},
          ),
        ),
      );

      // `flutter test` always runs in debug mode, so kDebugMode is true
      // here — this assertion documents that assumption rather than
      // hardcoding it, so the test fails loudly instead of silently if
      // that ever stops being true.
      expect(kDebugMode, isTrue);
      expect(find.text('Decryption failed: bad tag'), findsOneWidget);
    });

    testWidgets('does not throw when errorMessage is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          OfflinePlayerErrorView(
            aspectRatio: 16 / 9,
            errorMessage: null,
            onRetry: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });
  });
}
