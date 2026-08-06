import 'package:app/features/profile/presentation/widgets/settings_section/settings_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'settings_section_test_helpers.dart';

void main() {
  group('SettingsSectionHeader', () {
    testWidgets('renders the given title', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const SettingsSectionHeader(title: 'Settings')),
      );

      expect(find.text('Settings'), findsOneWidget);
    });
  });
}
