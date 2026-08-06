import 'package:app/features/profile/presentation/widgets/settings_section/settings_value_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'settings_section_test_helpers.dart';

void main() {
  group('SettingsValueDisplay', () {
    testWidgets('renders the given value and a forward chevron', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(const SettingsValueDisplay(value: 'Dark')),
      );

      expect(find.text('Dark'), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('truncates a long value with an ellipsis', (
      WidgetTester tester,
    ) async {
      const longValue =
          'A very long settings value that should not overflow the row';

      await tester.pumpWidget(
        buildTestableWidget(const SettingsValueDisplay(value: longValue)),
      );

      final text = tester.widget<Text>(find.text(longValue));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });
}
