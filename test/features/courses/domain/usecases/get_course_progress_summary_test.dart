import 'package:app/features/courses/domain/entities/course_progress_summary.dart';
import 'package:app/features/courses/domain/repositories/courses_repository.dart';
import 'package:app/features/courses/domain/usecases/get_course_progress_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockCoursesRepository extends Mock implements CoursesRepository {}

void main() {
  late GetCourseProgressSummary usecase;
  late MockCoursesRepository mockRepository;

  setUp(() {
    mockRepository = MockCoursesRepository();
    usecase = GetCourseProgressSummary(mockRepository);
  });

  const tCourseId = 'course-1';
  const tSummary = CourseProgressSummary(
    courseId: tCourseId,
    enrolledCount: 5,
    avgProgress: 42.0,
    completedCount: 1,
  );

  test('should get the course progress summary from the repository',
      () async {
    when(() => mockRepository.getCourseProgressSummary(tCourseId))
        .thenAnswer((_) async => const Right(tSummary));

    final result = await usecase(tCourseId);

    expect(result, const Right(tSummary));
    verify(() => mockRepository.getCourseProgressSummary(tCourseId));
    verifyNoMoreInteractions(mockRepository);
  });
}
