import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [child] with the localization + provider scaffolding every
/// player4 widget test needs. Shared across the split `player4/` test
/// files so each one stays focused on a single widget.
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
/// pure functions (like `mapPlayer4ErrorToMessage`) that take
/// [AppLocalizations] directly instead of a `BuildContext`.
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
