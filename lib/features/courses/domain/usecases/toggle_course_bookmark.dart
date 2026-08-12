import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../repositories/courses_repository.dart';

/// Adds or removes a bookmark for [courseId] depending on [isCurrentlyBookmarked].
///
/// Centralizing the add/remove decision here (instead of leaving the
/// `if (bookmarked) unbookmark else bookmark` branch inside the Riverpod
/// notifier) makes the toggle behavior independently unit-testable without
/// a WidgetTester/ProviderContainer harness.
class ToggleCourseBookmark {
  final CoursesRepository repository;

  ToggleCourseBookmark(this.repository);

  Future<Either<Failure, void>> call({
    required String courseId,
    required bool isCurrentlyBookmarked,
  }) async {
    return isCurrentlyBookmarked
        ? await repository.unbookmarkCourse(courseId)
        : await repository.bookmarkCourse(courseId);
  }
}
