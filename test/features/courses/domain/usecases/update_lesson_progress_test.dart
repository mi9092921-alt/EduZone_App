import 'package:app/features/courses/domain/repositories/courses_repository.dart';
import 'package:app/features/courses/domain/usecases/update_lesson_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockCoursesRepository extends Mock implements CoursesRepository {}

void main() {
  late UpdateLessonProgress usecase;
  late MockCoursesRepository mockRepository;

  setUp(() {
    mockRepository = MockCoursesRepository();
    usecase = UpdateLessonProgress(mockRepository);
  });

  const tCourseId = 'c1';
  const tLessonId = 'l1';
  const tCompleted = true;
  const tProgressPct = 100.0;
  const tWatchTimeSec = 120;

  test('should update lesson progress in the repository', () async {
    // arrange
    when(
      () => mockRepository.updateLessonProgress(
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
      () => mockRepository.updateLessonProgress(
        courseId: tCourseId,
        lessonId: tLessonId,
        completed: tCompleted,
        progressPct: tProgressPct,
        watchTimeSec: tWatchTimeSec,
      ),
    );
    verifyNoMoreInteractions(mockRepository);
  });
}
