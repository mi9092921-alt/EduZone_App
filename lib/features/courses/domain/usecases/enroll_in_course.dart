import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../repositories/courses_repository.dart';

/// Enrolls the current user in a course.
///
/// Kept as a thin pass-through to [CoursesRepository.enrollInCourse] on
/// purpose: the optimistic-UI rollback and analytics-event emission that
/// surround this call are UI-state concerns and stay in
/// `UserSubscriptions` (the Riverpod notifier). Only the actual
/// server/repository call — the part that is meaningful outside of a
/// widget/notifier context (e.g. reusable from tests or another entry
/// point) — is extracted here.
class EnrollInCourse {
  final CoursesRepository repository;

  EnrollInCourse(this.repository);

  Future<Either<Failure, void>> call(String courseId) async {
    return await repository.enrollInCourse(courseId);
  }
}
