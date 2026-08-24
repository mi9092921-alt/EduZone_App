import 'package:app/features/courses/data/services/watched_lessons_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WatchedLessonsService', () {
    test('a lesson that was never touched is not watched', () async {
      expect(await WatchedLessonsService.isLessonWatched('lesson-1'), false);
    });

    test('markLessonAsWatched persists true for that lesson only', () async {
      await WatchedLessonsService.markLessonAsWatched('lesson-1');

      expect(await WatchedLessonsService.isLessonWatched('lesson-1'), true);
      expect(
        await WatchedLessonsService.isLessonWatched('lesson-2'),
        false,
        reason: 'marking one lesson watched must not affect another lesson',
      );
    });

    test('clearLessonWatchedStatus resets a watched lesson back to false', () async {
      await WatchedLessonsService.markLessonAsWatched('lesson-1');
      expect(await WatchedLessonsService.isLessonWatched('lesson-1'), true);

      await WatchedLessonsService.clearLessonWatchedStatus('lesson-1');

      expect(await WatchedLessonsService.isLessonWatched('lesson-1'), false);
    });

    test('toggleWatchedStatus sets the exact value passed, both directions', () async {
      await WatchedLessonsService.toggleWatchedStatus('lesson-1', true);
      expect(await WatchedLessonsService.isLessonWatched('lesson-1'), true);

      await WatchedLessonsService.toggleWatchedStatus('lesson-1', false);
      expect(await WatchedLessonsService.isLessonWatched('lesson-1'), false);
    });

    test('the watched status of one lesson survives writes to another', () async {
      await WatchedLessonsService.markLessonAsWatched('lesson-a');
      await WatchedLessonsService.markLessonAsWatched('lesson-b');
      await WatchedLessonsService.clearLessonWatchedStatus('lesson-b');

      expect(
        await WatchedLessonsService.isLessonWatched('lesson-a'),
        true,
        reason: 'each lesson id must be stored under its own key',
      );
      expect(await WatchedLessonsService.isLessonWatched('lesson-b'), false);
    });
  });
}
