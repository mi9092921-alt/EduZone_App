// ignore_for_file: close_sinks

import 'dart:async';

import 'package:app/design_system/design_system.dart';
import 'package:app/features/video_player/presentation/widgets/player4/player4_controls_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'player4_test_helpers.dart';

void main() {
  group('Player4ControlsOverlay', () {
    Widget buildOverlay({
      bool showControls = true,
      VoidCallback? onToggleControls,
      VoidCallback? onTogglePlayback,
    }) {
      final playingController = StreamController<bool>.broadcast();
      final positionController = StreamController<Duration>.broadcast();
      final durationController = StreamController<Duration>.broadcast();

      return Builder(
        builder: (context) => Stack(
          children: [
            Player4ControlsOverlay(
              showControls: showControls,
              onToggleControls: onToggleControls ?? () {},
              isFullScreen: false,
              onExitFullScreen: () {},
              isMuted: false,
              onToggleMute: () {},
              speeds: const [1.0],
              currentSpeed: 1.0,
              onSpeedSelected: (_) {},
              targetQualities: const [],
              availableFormats: const [],
              selectedFormat: null,
              onQualitySelected: (_) {},
              onRewind: () {},
              onFastForward: () {},
              playingStream: playingController.stream,
              initialPlaying: false,
              onTogglePlayback: onTogglePlayback ?? () {},
              positionStream: positionController.stream,
              initialPosition: Duration.zero,
              durationStream: durationController.stream,
              initialDuration: const Duration(minutes: 1),
              onSeek: (_) {},
              ds: AppColors.of(context),
            ),
          ],
        ),
      );
    }

    testWidgets('renders the top bar, center controls, and seek bar together', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableWidget(buildOverlay()));

      // Play button from center controls, mute icon from top bar, slider
      // from the seek bar — confirms composition wired all three pieces.
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('ignores pointer events on inner controls when hidden', (
      WidgetTester tester,
    ) async {
      var toggledPlayback = false;

      await tester.pumpWidget(
        buildTestableWidget(
          buildOverlay(
            showControls: false,
            onTogglePlayback: () => toggledPlayback = true,
          ),
        ),
      );

      final ignorePointer = tester.widget<IgnorePointer>(
        find.descendant(
          of: find.byType(Player4ControlsOverlay),
          matching: find.byType(IgnorePointer),
        ),
      );
      expect(ignorePointer.ignoring, isTrue);

      await tester.tap(find.byIcon(Icons.play_arrow_rounded), warnIfMissed: false);
      await tester.pump();

      expect(toggledPlayback, isFalse);
    });

    testWidgets('tapping the background fires onToggleControls', (
      WidgetTester tester,
    ) async {
      var toggled = false;

      await tester.pumpWidget(
        buildTestableWidget(buildOverlay(onToggleControls: () => toggled = true)),
      );

      await tester.tapAt(const Offset(5, 5));
      await tester.pump();

      expect(toggled, isTrue);
    });
  });
}
