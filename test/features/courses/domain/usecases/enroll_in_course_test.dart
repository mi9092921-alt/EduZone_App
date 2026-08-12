import 'package:app/features/courses/domain/repositories/courses_repository.dart';
import 'package:app/features/courses/domain/usecases/enroll_in_course.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockCoursesRepository extends Mock implements CoursesRepository {}

void main() {
  late EnrollInCourse usecase;
  late MockCoursesRepository mockRepository;

  setUp(() {
    mockRepository = MockCoursesRepository();
    usecase = EnrollInCourse(mockRepository);
  });

  const tCourseId = 'course-1';

  test('should enroll the current user in the course via the repository',
      () async {
    when(() => mockRepository.enrollInCourse(tCourseId))
        .thenAnswer((_) async => const Right(null));

    final result = await usecase(tCourseId);

    expect(result, const Right(null));
    verify(() => mockRepository.enrollInCourse(tCourseId));
    verifyNoMoreInteractions(mockRepository);
  });
}
