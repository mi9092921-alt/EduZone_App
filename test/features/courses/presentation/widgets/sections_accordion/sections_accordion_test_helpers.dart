import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps [child] with the localization + provider scaffolding every
/// sections_accordion widget test needs. [overrides] lets individual tests
/// substitute fake providers (e.g. `downloadsProvider`) instead of hitting
/// real repositories.
Widget buildTestableWidget(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}
