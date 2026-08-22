import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/video_player/presentation/screens/video_player/player_switch_sheet.dart';
import 'package:app/features/video_player/presentation/screens/video_player/player_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestable(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  group('PlayerOptionTile', () {
    testWidgets('renders the given title, subtitle and icon', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          PlayerOptionTile(
            icon: Icons.auto_awesome_rounded,
            title: 'Modern',
            subtitle: 'Modern streaming',
            isActive: false,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Modern'), findsOneWidget);
      expect(find.text('Modern streaming'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });

    testWidgets('shows a check mark only when isActive is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestable(
          PlayerOptionTile(
            icon: Icons.auto_awesome_rounded,
            title: 'Modern',
            subtitle: 'Modern streaming',
            isActive: true,
            onTap: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      await tester.pumpWidget(
        buildTestable(
          PlayerOptionTile(
            icon: Icons.auto_awesome_rounded,
            title: 'Modern',
            subtitle: 'Modern streaming',
            isActive: false,
            onTap: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    });

    testWidgets('invokes onTap when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        buildTestable(
          PlayerOptionTile(
            icon: Icons.shield_rounded,
            title: 'Proxy',
            subtitle: 'Safer streaming',
            isActive: false,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(PlayerOptionTile));
      expect(tapped, isTrue);
    });
  });

  group('PlayerSwitchButton', () {
    testWidgets('shows the icon matching the youtube player type', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestable(
          const PlayerSwitchButton(
            courseId: 'c1',
            lessonId: 'l1',
            playerType: PlayerType.youtube,
          ),
        ),
      );

      expect(find.byIcon(Icons.smart_display_rounded), findsOneWidget);
    });

    testWidgets('tapping the button opens a sheet listing all 3 players', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestable(
          const PlayerSwitchButton(
            courseId: 'c1',
            lessonId: 'l1',
            playerType: PlayerType.youtube,
          ),
        ),
      );

      await tester.tap(find.byType(PlayerSwitchButton));
      await tester.pumpAndSettle();

      expect(find.byType(PlayerOptionTile), findsNWidgets(3));
    });

    testWidgets('marks the current playerType as the active option in the sheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestable(
          const PlayerSwitchButton(
            courseId: 'c1',
            lessonId: 'l1',
            playerType: PlayerType.modern,
          ),
        ),
      );

      await tester.tap(find.byType(PlayerSwitchButton));
      await tester.pumpAndSettle();

      final activeTile = tester.widget<PlayerOptionTile>(
        find.byWidgetPredicate(
          (w) => w is PlayerOptionTile && w.isActive,
        ),
      );
      expect(activeTile.icon, Icons.auto_awesome_rounded);
    });
  });
}
