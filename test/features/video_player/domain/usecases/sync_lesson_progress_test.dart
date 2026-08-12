import 'package:app/features/video_player/domain/entities/lesson_progress_sync_item.dart';
import 'package:app/features/video_player/domain/repositories/video_player_repository.dart';
import 'package:app/features/video_player/domain/usecases/sync_lesson_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockVideoPlayerRepository extends Mock implements VideoPlayerRepository {}

void main() {
  late SyncLessonProgress usecase;
  late MockVideoPlayerRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(<LessonProgressSyncItem>[]);
  });

  setUp(() {
    mockRepository = MockVideoPlayerRepository();
    usecase = SyncLessonProgress(mockRepository);
  });

  const tCourseId = 'course-1';
  const tLessonId = 'lesson-1';
  const tCompleted = true;
  const tProgressPct = 0.95;
  const tWatchTimeSec = 600;

  test('should delegate to repository.syncProgress', () async {
    when(
      () => mockRepository.syncProgressBatch(any()),
    ).thenAnswer((_) async => const Right(null));

    final result = await usecase(
      courseId: tCourseId,
      lessonId: tLessonId,
      completed: tCompleted,
      progressPct: tProgressPct,
      watchTimeSec: tWatchTimeSec,
    );

    expect(result, const Right(null));
    verify(
      () => mockRepository.syncProgressBatch(
        any(
          that: predicate<List<LessonProgressSyncItem>>((items) {
            return items.length == 1 &&
                items.single.courseId == tCourseId &&
                items.single.lessonId == tLessonId &&
                items.single.completed == tCompleted &&
                items.single.progressPct == tProgressPct &&
                items.single.watchTimeSec == tWatchTimeSec;
          }),
        ),
      ),
    ).called(1);
    verifyNoMoreInteractions(mockRepository);
  });
}
