import 'package:app/core/l10n/arb/app_localizations_ar.dart';
import 'package:app/core/l10n/arb/app_localizations_en.dart';
import 'package:app/features/courses/presentation/utils/course_format_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = AppLocalizationsEn();
  final ar = AppLocalizationsAr();

  group('formatCourseDuration', () {
    test('returns an empty string for zero minutes', () {
      expect(formatCourseDuration(0, en), '');
    });

    test('returns an empty string for negative minutes (defensive)', () {
      expect(formatCourseDuration(-5, en), '');
    });

    test('formats minutes-only durations under an hour', () {
      expect(formatCourseDuration(45, en), '45 ${en.minutes}');
    });

    test('formats whole-hour durations without a minutes part', () {
      expect(formatCourseDuration(60, en), '1 ${en.hours}');
      expect(formatCourseDuration(120, en), '2 ${en.hours}');
    });

    test('formats mixed hours-and-minutes durations', () {
      expect(formatCourseDuration(125, en), '2 ${en.hours} 5 ${en.minutes}');
    });

    test('never shows a bare "0 minutes" once there is a whole hour', () {
      // 60 minutes exactly must not render as "1 hr 0 min".
      final result = formatCourseDuration(60, en);
      expect(result.contains('0'), false);
    });

    test('uses the localized unit labels for the active locale (Arabic)', () {
      final result = formatCourseDuration(125, ar);
      expect(result, '2 ${ar.hours} 5 ${ar.minutes}');
    });
  });
}
