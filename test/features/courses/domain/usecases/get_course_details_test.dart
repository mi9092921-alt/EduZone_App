import 'package:app/features/courses/domain/entities/course.dart';
import 'package:app/features/courses/domain/repositories/courses_repository.dart';
import 'package:app/features/courses/domain/usecases/get_course_details.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockCoursesRepository extends Mock implements CoursesRepository {}

void main() {
  late GetCourseDetails usecase;
  late MockCoursesRepository mockRepository;

  setUp(() {
    mockRepository = MockCoursesRepository();
    usecase = GetCourseDetails(mockRepository);
  });

  const tCourseId = '1';
  const tCourse = Course(
    id: '1',
    tenantId: 'tenant1',
    title: 'Test Course',
    status: 'active',
  );

  test('should get course details from the repository', () async {
    // arrange
    when(
      () => mockRepository.getCourseDetails(tCourseId),
    ).thenAnswer((_) async => const Right(tCourse));

    // act
    final result = await usecase(tCourseId);

    // assert
    expect(result, const Right(tCourse));
    verify(() => mockRepository.getCourseDetails(tCourseId));
    verifyNoMoreInteractions(mockRepository);
  });
}
