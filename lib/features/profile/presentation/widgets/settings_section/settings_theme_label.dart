import 'package:flutter/material.dart';

import '../../../../../core/l10n/arb/app_localizations.dart';

/// Localized display label for a [ThemeMode] ("Light" / "Dark" / "System").
///
/// Pure function — didn't depend on any widget state in the original
/// `_getThemeLabel`, so it moves out unchanged and is now directly
/// unit-testable.
String themeModeLabel(ThemeMode mode, AppLocalizations l10n) {
  switch (mode) {
    case ThemeMode.light:
      return l10n.themeLight;
    case ThemeMode.dark:
      return l10n.themeDark;
    case ThemeMode.system:
      return l10n.themeSystem;
  }
}
