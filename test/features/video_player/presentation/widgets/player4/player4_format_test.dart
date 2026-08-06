import 'package:app/features/video_player/presentation/widgets/player4/player4_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatPlayer4Duration', () {
    test('formats zero as 0:00', () {
      expect(formatPlayer4Duration(Duration.zero), '0:00');
    });

    test('does not pad minutes but pads seconds', () {
      expect(formatPlayer4Duration(const Duration(minutes: 5, seconds: 3)), '5:03');
    });

    test('does not switch to an hours segment past 59 minutes', () {
      // Unlike the offline player's formatter, this one has always shown
      // raw total minutes (e.g. "63:05"), never "1:03:05". Preserved
      // exactly as the original behaved.
      expect(
        formatPlayer4Duration(const Duration(minutes: 63, seconds: 5)),
        '63:05',
      );
    });
  });
}
