import 'package:app/features/video_player/domain/repositories/video_player_repository.dart';
import 'package:app/features/video_player/domain/usecases/sync_lesson_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockVideoPlayerRepository extends Mock implements VideoPlayerRepository {}

void main() {
  late SyncLessonProgress usecase;
  late MockVideoPlayerRepository mockRepository;

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
    // arrange
    when(
      () => mockRepository.syncProgress(
        courseId: any(named: 'courseId'),
        lessonId: any(named: 'lessonId'),
        completed: any(named: 'completed'),
        progressPct: any(named: 'progressPct'),
        watchTimeSec: any(named: 'watchTimeSec'),
      ),
    ).thenAnswer((_) async => const Right(null));

    // act
    final result = await usecase(
      courseId: tCourseId,
      lessonId: tLessonId,
      completed: tCompleted,
      progressPct: tProgressPct,
      watchTimeSec: tWatchTimeSec,
    );

    // assert
    expect(result, const Right(null));
    verify(
      () => mockRepository.syncProgress(
        courseId: tCourseId,
        lessonId: tLessonId,
        completed: tCompleted,
        progressPct: tProgressPct,
        watchTimeSec: tWatchTimeSec,
      ),
    ).called(1);
    verifyNoMoreInteractions(mockRepository);
  });
}
