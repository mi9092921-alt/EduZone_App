import 'package:app/core/error/failures.dart';
import 'package:app/features/video_player/application/services/lesson_progress_sync_engine.dart';
import 'package:app/features/video_player/domain/entities/lesson_progress_sync_item.dart';
import 'package:app/features/video_player/domain/repositories/video_player_repository.dart';
import 'package:app/features/video_player/domain/usecases/sync_lesson_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockVideoPlayerRepository extends Mock implements VideoPlayerRepository {}

void main() {
  late MockVideoPlayerRepository repository;
  late LessonProgressSyncEngine engine;

  setUpAll(() {
    registerFallbackValue(<LessonProgressSyncItem>[]);
  });

  setUp(() {
    repository = MockVideoPlayerRepository();
    engine = LessonProgressSyncEngine(
      syncLessonProgress: SyncLessonProgress(repository),
      flushInterval: const Duration(milliseconds: 20),
      maxBatchSize: 3,
    );

    when(
      () => repository.syncProgressBatch(any()),
    ).thenAnswer((_) async => const Right(null));
  });

  tearDown(() async {
    await engine.dispose();
  });

  test('merges multiple progress updates for the same lesson', () async {
    engine
      ..enqueue(
        const LessonProgressSyncItem(
          courseId: 'c1',
          lessonId: 'l1',
          completed: false,
          progressPct: 10,
          watchTimeSec: 5,
        ),
      )
      ..enqueue(
        const LessonProgressSyncItem(
          courseId: 'c1',
          lessonId: 'l1',
          completed: false,
          progressPct: 40,
          watchTimeSec: 20,
        ),
        flushNow: true,
      );

    await Future<void>.delayed(Duration.zero);

    verify(
      () => repository.syncProgressBatch(
        any(
          that: predicate<List<LessonProgressSyncItem>>((items) {
            return items.length == 1 &&
                items.single.courseId == 'c1' &&
                items.single.lessonId == 'l1' &&
                items.single.progressPct == 40 &&
                items.single.watchTimeSec == 20;
          }),
        ),
      ),
    ).called(1);
  });

  test('ignores new progress after disposal', () async {
    await engine.dispose();

    engine.enqueue(
      const LessonProgressSyncItem(
        courseId: 'c1',
        lessonId: 'l1',
        completed: false,
        progressPct: 90,
      ),
    );

    await Future<void>.delayed(Duration.zero);

    expect(engine.pendingCount, 0);
    verifyNever(() => repository.syncProgressBatch(any()));
  });

  test('flushes and seals the queue at a session boundary', () async {
    engine.enqueue(
      const LessonProgressSyncItem(
        courseId: 'old-course',
        lessonId: 'old-lesson',
        completed: false,
        progressPct: 45,
      ),
    );

    await engine.closeSession(flushPending: true);

    verify(
      () => repository.syncProgressBatch(
        any(
          that: predicate<List<LessonProgressSyncItem>>(
            (items) => items.single.courseId == 'old-course',
          ),
        ),
      ),
    ).called(1);

    engine.openSession();
    engine.enqueue(
      const LessonProgressSyncItem(
        courseId: 'new-course',
        lessonId: 'new-lesson',
        completed: false,
        progressPct: 10,
      ),
      flushNow: true,
    );
    await Future<void>.delayed(Duration.zero);

    verify(
      () => repository.syncProgressBatch(
        any(
          that: predicate<List<LessonProgressSyncItem>>(
            (items) => items.single.courseId == 'new-course',
          ),
        ),
      ),
    ).called(1);
  });

  test('requeues the batch when sync fails', () async {
    when(
      () => repository.syncProgressBatch(any()),
    ).thenAnswer((_) async => const Left(ServerFailure('offline')));

    engine.enqueue(
      const LessonProgressSyncItem(
        courseId: 'c1',
        lessonId: 'l1',
        completed: false,
        progressPct: 10,
      ),
      flushNow: true,
    );

    await Future<void>.delayed(Duration.zero);

    expect(engine.pendingCount, 1);
  });
}
