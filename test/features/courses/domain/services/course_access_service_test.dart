import 'package:app/features/courses/domain/services/course_access_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CourseAccessService service;

  setUp(() {
    service = CourseAccessService();
  });

  group('CourseAccessService.resolve', () {
    test('returns enrolled when courseId is in subscriptions', () {
      final result = service.resolve(
        courseId: 'course-1',
        subscriptions: {'course-1', 'course-2'},
      );

      expect(result, CourseAccessState.enrolled);
    });

    test('returns notEnrolled when courseId is not in subscriptions', () {
      final result = service.resolve(
        courseId: 'course-3',
        subscriptions: {'course-1', 'course-2'},
      );

      expect(result, CourseAccessState.notEnrolled);
    });

    test('returns notEnrolled when subscriptions is empty', () {
      final result = service.resolve(
        courseId: 'course-1',
        subscriptions: const {},
      );

      expect(result, CourseAccessState.notEnrolled);
    });
  });
}
