import 'package:app/features/video_player/application/providers/video_provider.dart';
import 'package:app/features/video_player/domain/entities/lesson_progress_sync_item.dart';
import 'package:app/features/video_player/domain/repositories/video_player_repository.dart';
import 'package:app/features/video_player/domain/usecases/sync_lesson_progress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockVideoPlayerRepository extends Mock implements VideoPlayerRepository {}

class MockSyncLessonProgress extends Mock implements SyncLessonProgress {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const courseId = 'course-1';
  const lessonId = 'lesson-1';

  late ProviderContainer container;
  late MockVideoPlayerRepository mockRepo;
  late MockSyncLessonProgress mockSync;

  setUpAll(() {
    // Needed by mocktail for named-argument matchers like `any(named: ...)`
    // when the argument type isn't a primitive.
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(<LessonProgressSyncItem>[]);
  });

  setUp(() {
    mockRepo = MockVideoPlayerRepository();
    mockSync = MockSyncLessonProgress();

    when(
      () => mockSync.batch(any()),
    ).thenAnswer((_) async => const Right(null));

    when(() => mockRepo.logActivity(
          eventType: any(named: 'eventType'),
          metadata: any(named: 'metadata'),
        )).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        videoPlayerRepositoryProvider.overrideWithValue(mockRepo),
        syncLessonProgressProvider.overrideWithValue(mockSync),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('VideoProgress Notifier Tests', () {
    test('updateProgress updates state correctly', () {
      final notifier = container.read(
        videoProgressProvider(courseId, lessonId).notifier,
      );

      notifier.updateProgress(42.0, 120, courseId, lessonId);

      final state = container.read(videoProgressProvider(courseId, lessonId));
      expect(state.progressPct, 42.0);
      expect(state.watchTimeSec, 120);
      expect(state.isCompleted, false);
    });

    test('updateProgress auto-completes at 90% and syncs + logs immediately', () async {
      final notifier = container.read(
        videoProgressProvider(courseId, lessonId).notifier,
      );

      notifier.updateProgress(91.0, 600, courseId, lessonId);

      // Immediate sync + completion log are fire-and-forget async calls,
      // so pump the microtask queue before asserting.
      await Future<void>.delayed(Duration.zero);

      final state = container.read(videoProgressProvider(courseId, lessonId));
      expect(state.isCompleted, true);

      verify(
        () => mockSync.batch(
          any(
            that: predicate<List<LessonProgressSyncItem>>((items) {
              return items.length == 1 &&
                  items.single.courseId == courseId &&
                  items.single.lessonId == lessonId &&
                  items.single.completed &&
                  items.single.progressPct == 91.0 &&
                  items.single.watchTimeSec == 600;
            }),
          ),
        ),
      ).called(1);

      verify(() => mockRepo.logActivity(
            eventType: 'lesson_completed',
            metadata: {
              'course_id': courseId,
              'lesson_id': lessonId,
            },
          )).called(1);
    });

    test('updateProgress below 90% only schedules a debounced sync, no immediate call', () async {
      final notifier = container.read(
        videoProgressProvider(courseId, lessonId).notifier,
      );

      notifier.updateProgress(10.0, 30, courseId, lessonId);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => mockSync.batch(any()));
    });

    test('disposing the container triggers a final sync without throwing', () async {
      final notifier = container.read(
        videoProgressProvider(courseId, lessonId).notifier,
      );

      notifier.updateProgress(55.0, 200, courseId, lessonId);

      // This must not throw "Cannot use the Ref of ... after it has been
      // disposed." — that was the original bug this test guards against.
      expect(() => container.dispose(), returnsNormally);

      await Future<void>.delayed(Duration.zero);

      verify(
        () => mockSync.batch(
          any(
            that: predicate<List<LessonProgressSyncItem>>((items) {
              return items.length == 1 &&
                  items.single.courseId == courseId &&
                  items.single.lessonId == lessonId &&
                  !items.single.completed &&
                  items.single.progressPct == 55.0 &&
                  items.single.watchTimeSec == 200;
            }),
          ),
        ),
      ).called(1);
    });

    test('markAsCompleted syncs and logs only once even if called twice', () async {
      final notifier = container.read(
        videoProgressProvider(courseId, lessonId).notifier,
      );

      notifier.markAsCompleted(courseId, lessonId);
      notifier.markAsCompleted(courseId, lessonId);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(videoProgressProvider(courseId, lessonId));
      expect(state.isCompleted, true);

      verify(() => mockRepo.logActivity(
            eventType: 'lesson_completed',
            metadata: {
              'course_id': courseId,
              'lesson_id': lessonId,
            },
          )).called(1);
    });
  });
}
