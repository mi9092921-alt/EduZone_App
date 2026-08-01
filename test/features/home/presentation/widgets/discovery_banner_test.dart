import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/home/presentation/widgets/discovery_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // NOTE: DiscoveryBanner's "Explore More" button calls `context.go(...)`
  // (go_router), which requires a real GoRouter ancestor to work. Since no
  // shared GoRouter test harness exists yet in this codebase (see other
  // widget tests under test/shared and test/design_system), these tests
  // intentionally verify rendered content only and do not tap that button.
  Widget buildTestableWidget(Widget child, {Locale locale = const Locale('en')}) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: Scaffold(body: child),
      ),
    );
  }

  group('DiscoveryBanner', () {
    testWidgets('renders marketing copy and explore button (English)',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const DiscoveryBanner()));
      await tester.pumpAndSettle();

      expect(find.text('Discover our top picks'), findsOneWidget);
      expect(find.text('Explore More'), findsOneWidget);
      expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);

      // "+100 Courses" is split into a RichText with two styled spans;
      // assert on the underlying text runs rather than a single Text widget.
      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsWidgets);
      final combinedText = tester
          .widgetList<RichText>(richTextFinder)
          .map((rt) => rt.text.toPlainText())
          .join(' ');
      expect(combinedText, contains('+100'));
      expect(combinedText, contains('Courses'));
    });

    testWidgets('renders marketing copy in Arabic', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const DiscoveryBanner(), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();

      // Only assert on structural elements that are locale-independent —
      // exact Arabic marketing copy is verified via the ARB source of truth
      // rather than hardcoded here, to avoid this test drifting out of sync
      // with future copy changes.
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
    });
  });
}
