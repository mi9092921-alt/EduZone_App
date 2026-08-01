import 'package:app/features/courses/domain/repositories/courses_repository.dart';
import 'package:app/features/courses/domain/usecases/toggle_course_bookmark.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockCoursesRepository extends Mock implements CoursesRepository {}

void main() {
  late ToggleCourseBookmark usecase;
  late MockCoursesRepository mockRepository;

  setUp(() {
    mockRepository = MockCoursesRepository();
    usecase = ToggleCourseBookmark(mockRepository);
  });

  const tCourseId = 'course-1';

  test(
    'should call bookmarkCourse when the course is not currently bookmarked',
    () async {
      when(() => mockRepository.bookmarkCourse(tCourseId))
          .thenAnswer((_) async => const Right(null));

      final result = await usecase(
        courseId: tCourseId,
        isCurrentlyBookmarked: false,
      );

      expect(result, const Right(null));
      verify(() => mockRepository.bookmarkCourse(tCourseId)).called(1);
      verifyNever(() => mockRepository.unbookmarkCourse(any()));
    },
  );

  test(
    'should call unbookmarkCourse when the course is currently bookmarked',
    () async {
      when(() => mockRepository.unbookmarkCourse(tCourseId))
          .thenAnswer((_) async => const Right(null));

      final result = await usecase(
        courseId: tCourseId,
        isCurrentlyBookmarked: true,
      );

      expect(result, const Right(null));
      verify(() => mockRepository.unbookmarkCourse(tCourseId)).called(1);
      verifyNever(() => mockRepository.bookmarkCourse(any()));
    },
  );
}
