import 'package:app/features/courses/domain/entities/lesson_content.dart';
import 'package:app/features/courses/domain/repositories/courses_repository.dart';
import 'package:app/features/courses/domain/usecases/get_lesson_content.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockCoursesRepository extends Mock implements CoursesRepository {}

void main() {
  late GetLessonContent usecase;
  late MockCoursesRepository mockRepository;

  setUp(() {
    mockRepository = MockCoursesRepository();
    usecase = GetLessonContent(mockRepository);
  });

  const tLessonId = 'lesson-1';
  const tContent = LessonContent(
    lessonId: tLessonId,
    courseId: 'course-1',
    hasAccess: true,
  );

  test('should get the lesson content from the repository', () async {
    when(() => mockRepository.getLessonContent(tLessonId))
        .thenAnswer((_) async => const Right(tContent));

    final result = await usecase(tLessonId);

    expect(result, const Right(tContent));
    verify(() => mockRepository.getLessonContent(tLessonId));
    verifyNoMoreInteractions(mockRepository);
  });

  test(
    'should propagate a Left(Failure) when the repository denies access',
    () async {
      const tDenied = LessonContent(
        lessonId: tLessonId,
        courseId: '',
      );
      when(() => mockRepository.getLessonContent(tLessonId))
          .thenAnswer((_) async => const Right(tDenied));

      final result = await usecase(tLessonId);

      expect(
        result.getOrElse((_) => throw Exception()).hasAccess,
        isFalse,
      );
    },
  );
}
