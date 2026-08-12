import 'package:app/features/video_player/domain/repositories/video_player_repository.dart';
import 'package:app/features/video_player/domain/usecases/sync_lesson_progress.dart';
import 'package:app/features/video_player/application/providers/video_provider.dart';
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
  });

  setUp(() {
    mockRepo = MockVideoPlayerRepository();
    mockSync = MockSyncLessonProgress();

    when(() => mockSync.call(
          courseId: any(named: 'courseId'),
          lessonId: any(named: 'lessonId'),
          completed: any(named: 'completed'),
          progressPct: any(named: 'progressPct'),
          watchTimeSec: any(named: 'watchTimeSec'),
        )).thenAnswer((_) async => const Right(null));

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

      verify(() => mockSync.call(
            courseId: courseId,
            lessonId: lessonId,
            completed: true,
            progressPct: 91.0,
            watchTimeSec: 600,
          )).called(1);

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

      verifyNever(() => mockSync.call(
            courseId: any(named: 'courseId'),
            lessonId: any(named: 'lessonId'),
            completed: any(named: 'completed'),
            progressPct: any(named: 'progressPct'),
            watchTimeSec: any(named: 'watchTimeSec'),
          ));
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

      verify(() => mockSync.call(
            courseId: courseId,
            lessonId: lessonId,
            completed: false,
            progressPct: 55.0,
            watchTimeSec: 200,
          )).called(1);
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
