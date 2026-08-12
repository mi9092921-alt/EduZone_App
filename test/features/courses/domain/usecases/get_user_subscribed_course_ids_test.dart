import 'package:app/features/courses/domain/repositories/courses_repository.dart';
import 'package:app/features/courses/domain/usecases/get_user_subscribed_course_ids.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockCoursesRepository extends Mock implements CoursesRepository {}

void main() {
  late GetUserSubscribedCourseIds usecase;
  late MockCoursesRepository mockRepository;

  setUp(() {
    mockRepository = MockCoursesRepository();
    usecase = GetUserSubscribedCourseIds(mockRepository);
  });

  test('should get the subscribed course ids from the repository', () async {
    when(() => mockRepository.getUserSubscribedCourseIds())
        .thenAnswer((_) async => const Right({'c1', 'c2'}));

    final result = await usecase();

    expect(result, const Right({'c1', 'c2'}));
    verify(() => mockRepository.getUserSubscribedCourseIds());
    verifyNoMoreInteractions(mockRepository);
  });
}
