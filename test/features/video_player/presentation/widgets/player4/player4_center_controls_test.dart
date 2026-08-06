import 'dart:async';

import 'package:app/features/video_player/presentation/widgets/player4/player4_center_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'player4_test_helpers.dart';

void main() {
  group('Player4CenterControls', () {
    testWidgets('shows play icon when paused, pause icon when playing', (
      WidgetTester tester,
    ) async {
      final playingController = StreamController<bool>.broadcast();
      addTearDown(playingController.close);

      await tester.pumpWidget(
        buildTestableWidget(
          Player4CenterControls(
            isFullScreen: false,
            primaryColor: Colors.blue,
            onRewind: () {},
            onFastForward: () {},
            playingStream: playingController.stream,
            initialPlaying: false,
            onTogglePlayback: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      playingController.add(true);
      await tester.pump();

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('rewind/forward/play-pause buttons fire their callbacks', (
      WidgetTester tester,
    ) async {
      final playingController = StreamController<bool>.broadcast();
      addTearDown(playingController.close);

      var rewound = false;
      var forwarded = false;
      var toggled = false;

      await tester.pumpWidget(
        buildTestableWidget(
          Player4CenterControls(
            isFullScreen: false,
            primaryColor: Colors.blue,
            onRewind: () => rewound = true,
            onFastForward: () => forwarded = true,
            playingStream: playingController.stream,
            initialPlaying: false,
            onTogglePlayback: () => toggled = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.replay_10_rounded));
      await tester.tap(find.byIcon(Icons.forward_10_rounded));
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();

      expect(rewound, isTrue);
      expect(forwarded, isTrue);
      expect(toggled, isTrue);
    });
  });
}
