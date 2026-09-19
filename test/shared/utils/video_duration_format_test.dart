import 'package:app/shared/utils/video_duration_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatVideoDuration', () {
    test('formats zero as 0:00', () {
      expect(formatVideoDuration(Duration.zero), '0:00');
    });

    test('does not pad minutes but pads seconds', () {
      expect(formatVideoDuration(const Duration(minutes: 5, seconds: 3)), '5:03');
    });

    test('switches to an hours segment at one hour or longer', () {
      // Unified canonical behavior: the old player4 copy accumulated raw
      // total minutes past 59 (e.g. "63:05"); the shared formatter
      // switches to h:mm:ss instead, matching the other players.
      expect(
        formatVideoDuration(const Duration(minutes: 63, seconds: 5)),
        '1:03:05',
      );
      expect(
        formatVideoDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });

    test('does not pad the hours segment', () {
      expect(
        formatVideoDuration(const Duration(hours: 12, minutes: 5, seconds: 9)),
        '12:05:09',
      );
    });
  });

  group('formatVideoDurationPadded', () {
    test('formats zero as 00:00', () {
      expect(formatVideoDurationPadded(Duration.zero), '00:00');
    });

    test('formats seconds and minutes as mm:ss', () {
      expect(
        formatVideoDurationPadded(const Duration(minutes: 3, seconds: 5)),
        '03:05',
      );
    });

    test('formats under an hour without an hours segment', () {
      expect(
        formatVideoDurationPadded(const Duration(minutes: 59, seconds: 59)),
        '59:59',
      );
    });

    test('switches to hh:mm:ss once the duration is an hour or longer', () {
      expect(
        formatVideoDurationPadded(
          const Duration(hours: 1, minutes: 2, seconds: 3),
        ),
        '01:02:03',
      );
    });

    test('pads multi-hour durations correctly', () {
      expect(
        formatVideoDurationPadded(
          const Duration(hours: 12, minutes: 5, seconds: 9),
        ),
        '12:05:09',
      );
    });
  });
}
