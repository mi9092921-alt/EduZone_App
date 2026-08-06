import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps [child] with the localization + provider scaffolding every
/// offline-player widget test needs. Shared across the split
/// `offline_player/` test files so each one stays focused on a single
/// widget.
Widget buildTestableWidget(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}
