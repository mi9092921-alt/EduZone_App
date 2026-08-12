import 'dart:async';

import 'package:app/features/downloads/presentation/widgets/offline_player/offline_player_seek_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'offline_player_test_helpers.dart';

void main() {
  group('OfflinePlayerSeekSlider', () {
    testWidgets('renders the initial position and duration as mm:ss', (
      WidgetTester tester,
    ) async {
      final controller = StreamController<Duration>.broadcast();
      addTearDown(controller.close);

      await tester.pumpWidget(
        buildTestableWidget(
          OfflinePlayerSeekSlider(
            positionStream: controller.stream,
            initialPosition: const Duration(seconds: 30),
            getDuration: () => const Duration(minutes: 2),
            onSeek: (_) async {},
            onSeekEnd: () {},
          ),
        ),
      );

      expect(find.text('00:30'), findsOneWidget);
      expect(find.text('02:00'), findsOneWidget);
    });

    testWidgets('updates the elapsed time label as the position stream emits', (
      WidgetTester tester,
    ) async {
      final controller = StreamController<Duration>.broadcast();
      addTearDown(controller.close);

      await tester.pumpWidget(
        buildTestableWidget(
          OfflinePlayerSeekSlider(
            positionStream: controller.stream,
            initialPosition: Duration.zero,
            getDuration: () => const Duration(minutes: 1),
            onSeek: (_) async {},
            onSeekEnd: () {},
          ),
        ),
      );

      expect(find.text('00:00'), findsOneWidget);

      controller.add(const Duration(seconds: 45));
      await tester.pump();

      expect(find.text('00:45'), findsOneWidget);
    });

    testWidgets('disables the slider when duration is zero (still buffering)', (
      WidgetTester tester,
    ) async {
      final controller = StreamController<Duration>.broadcast();
      addTearDown(controller.close);

      await tester.pumpWidget(
        buildTestableWidget(
          OfflinePlayerSeekSlider(
            positionStream: controller.stream,
            initialPosition: Duration.zero,
            getDuration: () => Duration.zero,
            onSeek: (_) async {},
            onSeekEnd: () {},
          ),
        ),
      );

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.onChanged, isNull);
    });

    testWidgets('dragging the slider calls onSeek then onSeekEnd', (
      WidgetTester tester,
    ) async {
      final controller = StreamController<Duration>.broadcast();
      addTearDown(controller.close);

      Duration? seekedTo;
      var seekEndCalled = false;

      await tester.pumpWidget(
        buildTestableWidget(
          SizedBox(
            width: 300,
            child: OfflinePlayerSeekSlider(
              positionStream: controller.stream,
              initialPosition: Duration.zero,
              getDuration: () => const Duration(minutes: 10),
              onSeek: (position) async {
                seekedTo = position;
              },
              onSeekEnd: () {
                seekEndCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.drag(find.byType(Slider), const Offset(100, 0));
      await tester.pumpAndSettle();

      expect(seekedTo, isNotNull);
      expect(seekEndCalled, isTrue);
    });
  });
}
