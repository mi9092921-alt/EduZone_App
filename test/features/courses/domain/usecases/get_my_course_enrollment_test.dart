import 'package:app/features/courses/domain/entities/course_enrollment.dart';
import 'package:app/features/courses/domain/repositories/courses_repository.dart';
import 'package:app/features/courses/domain/usecases/get_my_course_enrollment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockCoursesRepository extends Mock implements CoursesRepository {}

void main() {
  late GetMyCourseEnrollment usecase;
  late MockCoursesRepository mockRepository;

  setUp(() {
    mockRepository = MockCoursesRepository();
    usecase = GetMyCourseEnrollment(mockRepository);
  });

  const tCourseId = 'course-1';
  const tEnrollment = CourseEnrollment(
    id: 'e1',
    userId: 'user-1',
    courseId: tCourseId,
    tenantId: 't1',
  );

  test('should get the enrollment for the course from the repository',
      () async {
    when(() => mockRepository.getMyCourseEnrollment(tCourseId))
        .thenAnswer((_) async => const Right(tEnrollment));

    final result = await usecase(tCourseId);

    expect(result, const Right(tEnrollment));
    verify(() => mockRepository.getMyCourseEnrollment(tCourseId));
    verifyNoMoreInteractions(mockRepository);
  });

  test('should return Right(null) when the user is not enrolled', () async {
    when(() => mockRepository.getMyCourseEnrollment(tCourseId))
        .thenAnswer((_) async => const Right(null));

    final result = await usecase(tCourseId);

    expect(result, const Right(null));
  });
}
