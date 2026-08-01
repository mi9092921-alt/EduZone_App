import 'package:app/features/courses/domain/entities/course.dart';
import 'package:app/features/courses/domain/repositories/courses_repository.dart';
import 'package:app/features/courses/domain/usecases/get_public_courses.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockCoursesRepository extends Mock implements CoursesRepository {}

void main() {
  late GetPublicCourses usecase;
  late MockCoursesRepository mockRepository;

  setUp(() {
    mockRepository = MockCoursesRepository();
    usecase = GetPublicCourses(mockRepository);
  });

  const tCourses = [
    Course(id: 'c1', tenantId: 't1', title: 'Course 1', status: 'published'),
  ];

  test('should use the default page and limit when none are provided',
      () async {
    when(() => mockRepository.getPublicCourses())
        .thenAnswer((_) async => const Right(tCourses));

    final result = await usecase();

    expect(result, const Right(tCourses));
    verify(() => mockRepository.getPublicCourses());
    verifyNoMoreInteractions(mockRepository);
  });

  test('should forward the given page and limit to the repository',
      () async {
    when(() => mockRepository.getPublicCourses(page: 2, limit: 20))
        .thenAnswer((_) async => const Right(tCourses));

    final result = await usecase(page: 2, limit: 20);

    expect(result, const Right(tCourses));
    verify(() => mockRepository.getPublicCourses(page: 2, limit: 20));
  });
}
