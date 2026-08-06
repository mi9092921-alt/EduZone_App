import 'package:app/features/profile/presentation/widgets/settings_section/settings_floating_graduation_icon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'settings_section_test_helpers.dart';

void main() {
  group('SettingsFloatingGraduationIcon', () {
    testWidgets('renders a graduation cap icon and animates without error', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(const SettingsFloatingGraduationIcon()),
      );

      expect(find.byType(FaIcon), findsOneWidget);

      // Pump through a couple of animation cycles to make sure the
      // repeating pulse animation doesn't throw.
      await tester.pump(const Duration(milliseconds: 750));
      await tester.pump(const Duration(milliseconds: 750));

      expect(find.byType(FaIcon), findsOneWidget);
    });
  });
}
