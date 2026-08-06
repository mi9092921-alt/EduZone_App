// ignore_for_file: avoid_redundant_argument_values

import 'package:app/design_system/design_system.dart';
import 'package:app/features/video_player/data/models/streaming_video_info.dart';
import 'package:app/features/video_player/presentation/widgets/player4/player4_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'player4_test_helpers.dart';

StreamingFormat _format(String quality) => StreamingFormat(
  quality: quality,
  ext: 'mp4',
  hasAudio: true,
  requiresMerge: false,
  videoUrl: 'https://example.com/$quality.mp4',
);

void main() {
  group('Player4TopBar', () {
    Widget buildTopBar({
      bool isFullScreen = false,
      VoidCallback? onExitFullScreen,
      bool isMuted = false,
      VoidCallback? onToggleMute,
      ValueChanged<double>? onSpeedSelected,
      List<StreamingFormat>? availableFormats,
      StreamingFormat? selectedFormat,
      ValueChanged<StreamingFormat>? onQualitySelected,
    }) {
      return Builder(
        builder: (context) => Player4TopBar(
          isFullScreen: isFullScreen,
          onExitFullScreen: onExitFullScreen ?? () {},
          isMuted: isMuted,
          onToggleMute: onToggleMute ?? () {},
          speeds: const [0.5, 1.0, 1.5, 2.0],
          currentSpeed: 1.0,
          onSpeedSelected: onSpeedSelected ?? (_) {},
          targetQualities: const ['1080p', '720p', '480p'],
          availableFormats: availableFormats ?? [_format('720p')],
          selectedFormat: selectedFormat,
          onQualitySelected: onQualitySelected ?? (_) {},
          ds: AppColors.of(context),
        ),
      );
    }

    testWidgets('shows a fullscreen-exit button only when isFullScreen is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableWidget(buildTopBar(isFullScreen: false)));
      expect(find.byIcon(Icons.fullscreen_exit_rounded), findsNothing);

      await tester.pumpWidget(buildTestableWidget(buildTopBar(isFullScreen: true)));
      expect(find.byIcon(Icons.fullscreen_exit_rounded), findsOneWidget);
    });

    testWidgets('fires onExitFullScreen when the exit button is tapped', (
      WidgetTester tester,
    ) async {
      var exited = false;
      await tester.pumpWidget(
        buildTestableWidget(
          buildTopBar(isFullScreen: true, onExitFullScreen: () => exited = true),
        ),
      );

      await tester.tap(find.byIcon(Icons.fullscreen_exit_rounded));
      await tester.pump();

      expect(exited, isTrue);
    });

    testWidgets('shows the mute icon based on isMuted and fires onToggleMute', (
      WidgetTester tester,
    ) async {
      var toggled = false;
      await tester.pumpWidget(
        buildTestableWidget(
          buildTopBar(isMuted: false, onToggleMute: () => toggled = true),
        ),
      );

      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pump();

      expect(toggled, isTrue);
    });

    testWidgets('opening the quality menu only lists qualities that are available', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          buildTopBar(availableFormats: [_format('720p60')]),
        ),
      );

      await tester.tap(find.byIcon(Icons.settings_suggest_rounded));
      await tester.pumpAndSettle();

      expect(find.text('720p'), findsOneWidget);
      expect(find.text('1080p'), findsNothing);
      expect(find.text('480p'), findsNothing);
    });
  });
}
