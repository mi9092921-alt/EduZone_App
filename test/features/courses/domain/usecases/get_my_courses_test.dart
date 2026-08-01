import 'package:app/features/courses/domain/entities/course_enrollment.dart';
import 'package:app/features/courses/domain/repositories/courses_repository.dart';
import 'package:app/features/courses/domain/usecases/get_my_courses.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockCoursesRepository extends Mock implements CoursesRepository {}

void main() {
  late GetMyCourses usecase;
  late MockCoursesRepository mockRepository;

  setUp(() {
    mockRepository = MockCoursesRepository();
    usecase = GetMyCourses(mockRepository);
  });

  final List<CourseEnrollment> tEnrollments = [
    const CourseEnrollment(
      id: '1',
      courseId: 'c1',
      userId: 'u1',
      tenantId: 'tenant1',
      progressAvg: 50.0,
    ),
  ];

  test('should get enrolled courses from the repository', () async {
    // arrange
    when(
      () => mockRepository.getMyCourses(),
    ).thenAnswer((_) async => Right(tEnrollments));

    // act
    final result = await usecase();

    // assert
    expect(result, Right(tEnrollments));
    verify(() => mockRepository.getMyCourses());
    verifyNoMoreInteractions(mockRepository);
  });
}
