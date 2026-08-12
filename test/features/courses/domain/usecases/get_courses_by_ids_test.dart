import 'package:app/features/courses/domain/entities/course.dart';
import 'package:app/features/courses/domain/repositories/courses_repository.dart';
import 'package:app/features/courses/domain/usecases/get_courses_by_ids.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockCoursesRepository extends Mock implements CoursesRepository {}

void main() {
  late GetCoursesByIds usecase;
  late MockCoursesRepository mockRepository;

  setUp(() {
    mockRepository = MockCoursesRepository();
    usecase = GetCoursesByIds(mockRepository);
  });

  const tIds = ['c1', 'c2'];
  const tCourses = [
    Course(id: 'c1', tenantId: 't1', title: 'Course 1', status: 'published'),
    Course(id: 'c2', tenantId: 't1', title: 'Course 2', status: 'published'),
  ];

  test('should get the courses matching the given ids from the repository',
      () async {
    when(() => mockRepository.getCoursesByIds(tIds))
        .thenAnswer((_) async => const Right(tCourses));

    final result = await usecase(tIds);

    expect(result, const Right(tCourses));
    verify(() => mockRepository.getCoursesByIds(tIds));
    verifyNoMoreInteractions(mockRepository);
  });
}
