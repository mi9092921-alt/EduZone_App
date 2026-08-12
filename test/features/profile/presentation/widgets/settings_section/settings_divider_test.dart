import 'package:app/features/profile/presentation/widgets/settings_section/settings_divider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'settings_section_test_helpers.dart';

void main() {
  group('SettingsDivider', () {
    testWidgets('renders a Divider with the given color at reduced opacity', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(const SettingsDivider(color: Colors.blue)),
      );

      final divider = tester.widget<Divider>(find.byType(Divider));
      expect(divider.color, Colors.blue.withValues(alpha: 0.5));
      expect(divider.indent, 72);
    });
  });
}
