import 'package:app/features/downloads/presentation/widgets/offline_player/offline_player_controls_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'offline_player_test_helpers.dart';

void main() {
  group('OfflinePlayerControlsOverlay', () {
    Widget buildOverlay({
      bool showControls = true,
      bool isPlaying = false,
      bool isFullScreen = false,
      VoidCallback? onToggleControls,
      VoidCallback? onTogglePlayback,
      VoidCallback? onRewind,
      VoidCallback? onFastForward,
      VoidCallback? onCycleSpeed,
      VoidCallback? onFullscreenToggle,
    }) {
      return OfflinePlayerControlsOverlay(
        showControls: showControls,
        onToggleControls: onToggleControls ?? () {},
        seekSlider: const SizedBox(key: Key('fake-seek-slider')),
        isPlaying: isPlaying,
        onTogglePlayback: onTogglePlayback ?? () {},
        onRewind: onRewind ?? () {},
        onFastForward: onFastForward ?? () {},
        speedLabel: '1.0x',
        onCycleSpeed: onCycleSpeed ?? () {},
        isFullScreen: isFullScreen,
        onFullscreenToggle: onFullscreenToggle ?? () {},
      );
    }

    testWidgets('shows the play icon when paused and pause icon when playing', (
      WidgetTester tester,
    ) async {
      // ignore: avoid_redundant_argument_values
      await tester.pumpWidget(buildTestableWidget(buildOverlay(isPlaying: false)));
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      await tester.pumpWidget(buildTestableWidget(buildOverlay(isPlaying: true)));
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('shows the fullscreen-exit icon when already fullscreen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableWidget(buildOverlay(isFullScreen: true)));
      expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
    });

    testWidgets('renders the composed seek slider via composition', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableWidget(buildOverlay()));
      expect(find.byKey(const Key('fake-seek-slider')), findsOneWidget);
    });

    testWidgets('displays the given speed label and fires onCycleSpeed on tap', (
      WidgetTester tester,
    ) async {
      var cycled = false;
      await tester.pumpWidget(
        buildTestableWidget(buildOverlay(onCycleSpeed: () => cycled = true)),
      );

      expect(find.text('1.0x'), findsOneWidget);
      await tester.tap(find.text('1.0x'));
      await tester.pump();

      expect(cycled, isTrue);
    });

    testWidgets('rewind/fast-forward/fullscreen buttons fire their callbacks', (
      WidgetTester tester,
    ) async {
      var rewound = false;
      var forwarded = false;
      var toggledFullscreen = false;

      await tester.pumpWidget(
        buildTestableWidget(
          buildOverlay(
            onRewind: () => rewound = true,
            onFastForward: () => forwarded = true,
            onFullscreenToggle: () => toggledFullscreen = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.replay_10));
      await tester.tap(find.byIcon(Icons.forward_10));
      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pump();

      expect(rewound, isTrue);
      expect(forwarded, isTrue);
      expect(toggledFullscreen, isTrue);
    });

    testWidgets('ignores taps on inner controls when showControls is false', (
      WidgetTester tester,
    ) async {
      var toggled = false;
      await tester.pumpWidget(
        buildTestableWidget(
          buildOverlay(
            showControls: false,
            onTogglePlayback: () => toggled = true,
          ),
        ),
      );

      final ignorePointer = tester.widget<IgnorePointer>(
        find.byType(IgnorePointer),
      );
      expect(ignorePointer.ignoring, isTrue);

      // The inner play/pause button is present but pointer-ignored — taps
      // must fall through to the outer GestureDetector's onToggleControls,
      // not reach onTogglePlayback.
      await tester.tap(find.byIcon(Icons.play_arrow_rounded), warnIfMissed: false);
      await tester.pump();

      expect(toggled, isFalse);
    });
  });
}
