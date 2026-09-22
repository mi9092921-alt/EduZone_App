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
      expect(
        await WatchedLessonsService.isLessonWatched('user-1', 'lesson-1'),
        false,
      );
    });

    test('markLessonAsWatched persists true for that lesson only', () async {
      await WatchedLessonsService.markLessonAsWatched('user-1', 'lesson-1');

      expect(
        await WatchedLessonsService.isLessonWatched('user-1', 'lesson-1'),
        true,
      );
      expect(
        await WatchedLessonsService.isLessonWatched('user-1', 'lesson-2'),
        false,
        reason: 'marking one lesson watched must not affect another lesson',
      );
    });

    test('clearLessonWatchedStatus resets a watched lesson back to false', () async {
      await WatchedLessonsService.markLessonAsWatched('user-1', 'lesson-1');
      expect(
        await WatchedLessonsService.isLessonWatched('user-1', 'lesson-1'),
        true,
      );

      await WatchedLessonsService.clearLessonWatchedStatus('user-1', 'lesson-1');

      expect(
        await WatchedLessonsService.isLessonWatched('user-1', 'lesson-1'),
        false,
      );
    });

    test('toggleWatchedStatus sets the exact value passed, both directions', () async {
      await WatchedLessonsService.toggleWatchedStatus('user-1', 'lesson-1', true);
      expect(
        await WatchedLessonsService.isLessonWatched('user-1', 'lesson-1'),
        true,
      );

      await WatchedLessonsService.toggleWatchedStatus('user-1', 'lesson-1', false);
      expect(
        await WatchedLessonsService.isLessonWatched('user-1', 'lesson-1'),
        false,
      );
    });

    test('the watched status of one lesson survives writes to another', () async {
      await WatchedLessonsService.markLessonAsWatched('user-1', 'lesson-a');
      await WatchedLessonsService.markLessonAsWatched('user-1', 'lesson-b');
      await WatchedLessonsService.clearLessonWatchedStatus('user-1', 'lesson-b');

      expect(
        await WatchedLessonsService.isLessonWatched('user-1', 'lesson-a'),
        true,
        reason: 'each lesson id must be stored under its own key',
      );
      expect(
        await WatchedLessonsService.isLessonWatched('user-1', 'lesson-b'),
        false,
      );
    });
  });

  // Phase 9 account isolation: the watched flags are optimistic hints that
  // survive an app kill or a passive session revocation (neither path runs
  // the logout SharedPreferences wipe). Their keys must therefore be scoped
  // per account, or the next account signing in on the same device would
  // load and display the previous account's watched state as its own.
  group('WatchedLessonsService — account isolation', () {
    test("user B's read never resolves user A's watched flag", () async {
      await WatchedLessonsService.markLessonAsWatched('user-A', 'lesson-1');

      expect(
        await WatchedLessonsService.isLessonWatched('user-B', 'lesson-1'),
        false,
        reason:
            'watched hints are account-scoped: a different account signing '
            'in on the same device must not see them',
      );
      expect(
        await WatchedLessonsService.isLessonWatched('user-A', 'lesson-1'),
        true,
      );
    });

    test("user B's toggle writes a separate key and leaves A's data intact",
        () async {
      await WatchedLessonsService.toggleWatchedStatus('user-A', 'lesson-1', true);
      await WatchedLessonsService.toggleWatchedStatus('user-B', 'lesson-1', true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), containsAll(<String>[
        'watched_lesson_user-A_lesson-1',
        'watched_lesson_user-B_lesson-1',
      ]));

      await WatchedLessonsService.toggleWatchedStatus('user-B', 'lesson-1', false);
      expect(
        await WatchedLessonsService.isLessonWatched('user-A', 'lesson-1'),
        true,
        reason: "reverting B's hint must not touch A's stored hint",
      );
    });

    test('an empty owner never touches disk', () async {
      await WatchedLessonsService.toggleWatchedStatus('', 'lesson-1', true);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((key) => key.startsWith('watched_lesson_')),
        isEmpty,
        reason: 'without an owner there is no account to scope the write to',
      );
      expect(
        await WatchedLessonsService.isLessonWatched('', 'lesson-1'),
        false,
      );
    });
  });
}
