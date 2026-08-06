import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] with the localization + provider scaffolding every
/// settings_section widget test needs.
Widget buildTestableWidget(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

/// Runs [callback] with a resolved [AppLocalizations] instance, for testing
/// pure functions that take [AppLocalizations] directly instead of a
/// `BuildContext`.
Future<void> withLocalizations(
  WidgetTester tester,
  void Function(AppLocalizations l10n) callback,
) async {
  late AppLocalizations l10n;
  await tester.pumpWidget(
    buildTestableWidget(
      Builder(
        builder: (context) {
          l10n = AppLocalizations.of(context)!;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  callback(l10n);
}
