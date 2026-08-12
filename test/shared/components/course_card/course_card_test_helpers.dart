import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps [child] with the localization + provider scaffolding every course
/// card widget test needs. Shared across the split `course_card/` test
/// files so each one stays focused on a single card widget.
Widget buildTestableWidget(Widget child, {Locale locale = const Locale('en')}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}
