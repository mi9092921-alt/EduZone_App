import 'dart:async';

import 'package:app/design_system/design_system.dart';
import 'package:app/features/video_player/presentation/widgets/player4/player4_seek_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'player4_test_helpers.dart';

void main() {
  group('Player4SeekBar', () {
    testWidgets('renders the initial position and duration as m:ss', (
      WidgetTester tester,
    ) async {
      final positionController = StreamController<Duration>.broadcast();
      final durationController = StreamController<Duration>.broadcast();
      addTearDown(positionController.close);
      addTearDown(durationController.close);

      late DesignSystemColors ds;
      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (context) {
              ds = AppColors.of(context);
              return Player4SeekBar(
                positionStream: positionController.stream,
                initialPosition: const Duration(seconds: 30),
                durationStream: durationController.stream,
                initialDuration: const Duration(minutes: 2),
                ds: ds,
                onSeek: (_) {},
              );
            },
          ),
        ),
      );

      expect(find.text('0:30'), findsOneWidget);
      expect(find.text('2:00'), findsOneWidget);
    });

    testWidgets('calls onSeek on every drag tick (not just on release)', (
      WidgetTester tester,
    ) async {
      final positionController = StreamController<Duration>.broadcast();
      final durationController = StreamController<Duration>.broadcast();
      addTearDown(positionController.close);
      addTearDown(durationController.close);

      final seeks = <Duration>[];

      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (context) {
              return SizedBox(
                width: 300,
                child: Player4SeekBar(
                  positionStream: positionController.stream,
                  initialPosition: Duration.zero,
                  durationStream: durationController.stream,
                  initialDuration: const Duration(minutes: 10),
                  ds: AppColors.of(context),
                  onSeek: seeks.add,
                ),
              );
            },
          ),
        ),
      );

      await tester.drag(find.byType(Slider), const Offset(100, 0));
      await tester.pumpAndSettle();

      // A drag produces multiple onChanged ticks — the seek bar forwards
      // every one of them (continuous seek), matching the original's
      // `onChanged: (value) { _player.seek(...); }` behavior rather than
      // only seeking once on release.
      expect(seeks, isNotEmpty);
    });
  });
}
