import 'package:app/features/downloads/presentation/widgets/offline_player/offline_player_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatPlayerDuration', () {
    test('formats zero as 00:00', () {
      expect(formatPlayerDuration(Duration.zero), '00:00');
    });

    test('formats seconds and minutes as mm:ss', () {
      expect(formatPlayerDuration(const Duration(minutes: 3, seconds: 5)), '03:05');
    });

    test('formats under an hour without an hours segment', () {
      expect(formatPlayerDuration(const Duration(minutes: 59, seconds: 59)), '59:59');
    });

    test('switches to hh:mm:ss once the duration is an hour or longer', () {
      expect(
        formatPlayerDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '01:02:03',
      );
    });

    test('pads multi-hour durations correctly', () {
      expect(
        formatPlayerDuration(const Duration(hours: 12, minutes: 5, seconds: 9)),
        '12:05:09',
      );
    });
  });
}
