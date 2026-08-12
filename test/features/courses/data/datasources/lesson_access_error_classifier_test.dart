import 'package:app/features/courses/data/datasources/lesson_access_error_classifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('LessonAccessErrorClassifier.isAccessDenied', () {
    test(
      'returns true for a P0001 error whose message mentions ACCESS_DENIED',
      () {
        const e = PostgrestException(
          message: 'ACCESS_DENIED: user is not enrolled in this course',
          code: 'P0001',
        );

        expect(LessonAccessErrorClassifier.isAccessDenied(e), isTrue);
      },
    );

    test(
      'returns true for a P0001 error whose message mentions not_enrolled',
      () {
        const e = PostgrestException(
          message: 'not_enrolled',
          code: 'P0001',
        );

        expect(LessonAccessErrorClassifier.isAccessDenied(e), isTrue);
      },
    );

    test(
      'returns false for a P0001 error with an unrelated message '
      '(regression test: P0001 alone must not be treated as access denied)',
      () {
        const e = PostgrestException(
          message: 'lesson_not_found: no lesson with that id',
          code: 'P0001',
        );

        expect(LessonAccessErrorClassifier.isAccessDenied(e), isFalse);
      },
    );

    test(
      'returns false when the message mentions ACCESS_DENIED but the code '
      'is not a user-raised code (e.g. a real DB/infra error)',
      () {
        const e = PostgrestException(
          message: 'connection to ACCESS_DENIED bucket failed',
          code: '08006', // connection_failure
        );

        expect(LessonAccessErrorClassifier.isAccessDenied(e), isFalse);
      },
    );

    test('returns false when code is null', () {
      const e = PostgrestException(
        message: 'ACCESS_DENIED: not enrolled',
      );

      expect(LessonAccessErrorClassifier.isAccessDenied(e), isFalse);
    });

    test('returns false for an unrelated P0001 error with no known marker',
        () {
      const e = PostgrestException(
        message: 'division by zero',
        code: 'P0001',
      );

      expect(LessonAccessErrorClassifier.isAccessDenied(e), isFalse);
    });
  });
}
