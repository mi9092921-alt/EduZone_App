import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_initializer.dart';

part 'app_providers.g.dart';

@riverpod
class AppThemeMode extends _$AppThemeMode {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() => _loadTheme();

  static ThemeMode _loadTheme() {
    final value = AppInitializer.prefs.getString(_key);
    if (value == 'dark') return ThemeMode.dark;
    if (value == 'light') return ThemeMode.light;
    return ThemeMode.system;
  }

  void updateTheme(ThemeMode mode) {
    state = mode;
    AppInitializer.prefs.setString(_key, mode.name);
  }
}

@riverpod
class AppLocale extends _$AppLocale {
  static const _key = 'app_locale';

  @override
  Locale build() => _loadLocale();

  static Locale _loadLocale() {
    final value = AppInitializer.prefs.getString(_key);
    if (value == 'ar') return const Locale('ar');
    return const Locale('en');
  }

  void updateLocale(Locale locale) {
    state = locale;
    AppInitializer.prefs.setString(_key, locale.languageCode);
  }
}
