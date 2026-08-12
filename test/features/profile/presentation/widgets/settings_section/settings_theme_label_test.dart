import 'package:app/features/profile/presentation/widgets/settings_section/settings_theme_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'settings_section_test_helpers.dart';

void main() {
  group('themeModeLabel', () {
    testWidgets('returns the localized label for each ThemeMode', (
      WidgetTester tester,
    ) async {
      await withLocalizations(tester, (l10n) {
        expect(themeModeLabel(ThemeMode.light, l10n), l10n.themeLight);
        expect(themeModeLabel(ThemeMode.dark, l10n), l10n.themeDark);
        expect(themeModeLabel(ThemeMode.system, l10n), l10n.themeSystem);
      });
    });
  });
}
