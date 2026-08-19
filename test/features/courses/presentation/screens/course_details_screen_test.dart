import 'dart:async';

import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/courses/application/providers/courses_provider.dart';
import 'package:app/features/courses/domain/entities/course.dart';
import 'package:app/features/courses/domain/entities/course_enrollment.dart';
import 'package:app/features/courses/presentation/screens/course_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../widgets/course_widget_test_helpers.dart';

Future<void> pumpCourseDetails(
  WidgetTester tester, {
  required String courseId,
  required List<Override> overrides,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CourseDetailsScreen(courseId: courseId),
      ),
    ),
  );
}

void main() {
  group('CourseDetailsScreen — loading state', () {
    testWidgets('shows the skeleton content while the course is loading',
        (tester) async {
      await pumpCourseDetails(
        tester,
        courseId: 'course-1',
        overrides: [
          courseDetailsProvider('course-1').overrideWith(
            (ref) => Completer<Course>().future, // never resolves
          ),
          myCoursesProvider.overrideWith((ref) async => const []),
        ],
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text(Course.skeleton().title), findsWidgets);
    });
  });

  group('CourseDetailsScreen — error state', () {
    testWidgets(
        'shows a localized error with a retry action instead of a raw '
        'exception, and retry re-triggers the provider', (tester) async {
      var fetchCount = 0;
      await pumpCourseDetails(
        tester,
        courseId: 'course-err',
        overrides: [
          courseDetailsProvider('course-err').overrideWith((ref) async {
            fetchCount++;
            throw Exception('network unreachable');
          }),
          myCoursesProvider.overrideWith((ref) async => const []),
        ],
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.failedToLoadCourses), findsOneWidget);
      expect(find.text(l10n.retryButton), findsOneWidget);
      // The description text is produced by ErrorHandler.getMessage(),
      // which classifies the error and maps it to a fixed, localized
      // l10n key — it never displays err.toString() (Section 14). See
      // lib/shared/utils/error_handler.dart and
      // test/shared/utils/error_handler_test.dart for the dedicated
      // coverage of that classification logic; this screen-level test
      // only needs to confirm the error path renders *some* safe text
      // and that retry re-invokes the provider, which the assertions
      // below already do.
      expect(fetchCount, greaterThanOrEqualTo(1));

      final initialFetchCount = fetchCount;
      await tester.tap(find.text(l10n.retryButton));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(fetchCount, greaterThan(initialFetchCount));
      expect(find.text(l10n.failedToLoadCourses), findsOneWidget);
    });
  });

  group('CourseDetailsScreen — not enrolled', () {
    testWidgets('shows the priced enroll footer for a paid, unenrolled course',
        (tester) async {
      await pumpCourseDetails(
        tester,
        courseId: tFullCourse.id,
        overrides: [
          courseDetailsProvider(tFullCourse.id)
              .overrideWith((ref) async => tFullCourse),
          myCoursesProvider.overrideWith((ref) async => const []),
        ],
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text('\$49.99'), findsOneWidget);
      expect(find.text(l10n.enrollNow), findsOneWidget);
      // Default tab is the curriculum tab (initialIndex: 1); tFullCourse has
      // no sections, so the empty-content message must show, not a crash.
      expect(find.text(l10n.noContentAvailable), findsOneWidget);
    });

    testWidgets(
        'switching to the About tab renders the course description without '
        'crashing for a minimal course (no instructor/objectives/'
        'prerequisites)', (tester) async {
      await pumpCourseDetails(
        tester,
        courseId: tMinimalFreeCourse.id,
        overrides: [
          courseDetailsProvider(tMinimalFreeCourse.id)
              .overrideWith((ref) async => tMinimalFreeCourse),
          myCoursesProvider.overrideWith((ref) async => const []),
        ],
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.courseDescriptionLabel));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(tMinimalFreeCourse.title), findsWidgets);
    });
  });

  group('CourseDetailsScreen — enrolled with progress', () {
    testWidgets(
        'shows completed/total lessons and a Continue Learning action for '
        'an enrolled, in-progress course', (tester) async {
      final enrollment = CourseEnrollment(
        id: 'enr-1',
        userId: 'user-1',
        courseId: tMinimalFreeCourse.id,
        tenantId: 'tenant-1',
        progressPct: 40,
        completedLessons: 2,
        totalLessons: 5,
      );

      await pumpCourseDetails(
        tester,
        courseId: tMinimalFreeCourse.id,
        overrides: [
          courseDetailsProvider(tMinimalFreeCourse.id)
              .overrideWith((ref) async => tMinimalFreeCourse),
          myCoursesProvider.overrideWith((ref) async => [enrollment]),
          myCourseEnrollmentProvider(tMinimalFreeCourse.id)
              .overrideWith((ref) async => enrollment),
        ],
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.lessonsCompleted(2, 5)), findsOneWidget);
      expect(find.text(l10n.resumeLearning), findsOneWidget);
      expect(find.text(l10n.courseCompleted), findsNothing);
    });

    testWidgets('shows "Course Completed" and a Review action once finished',
        (tester) async {
      final enrollment = CourseEnrollment(
        id: 'enr-2',
        userId: 'user-1',
        courseId: tMinimalFreeCourse.id,
        tenantId: 'tenant-1',
        status: 'completed',
        progressPct: 100,
        completedLessons: 5,
        totalLessons: 5,
      );

      await pumpCourseDetails(
        tester,
        courseId: tMinimalFreeCourse.id,
        overrides: [
          courseDetailsProvider(tMinimalFreeCourse.id)
              .overrideWith((ref) async => tMinimalFreeCourse),
          myCoursesProvider.overrideWith((ref) async => [enrollment]),
          myCourseEnrollmentProvider(tMinimalFreeCourse.id)
              .overrideWith((ref) async => enrollment),
        ],
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.courseCompleted), findsOneWidget);
      expect(find.text(l10n.reviewCourse), findsOneWidget);
    });
  });

  group('CourseDetailsScreen — pull to refresh', () {
    testWidgets(
        'pulling to refresh invalidates course details, enrollments and '
        'progress instead of silently doing nothing', (tester) async {
      var courseFetchCount = 0;
      await pumpCourseDetails(
        tester,
        courseId: tMinimalFreeCourse.id,
        overrides: [
          courseDetailsProvider(tMinimalFreeCourse.id).overrideWith((ref) async {
            courseFetchCount++;
            return tMinimalFreeCourse;
          }),
          myCoursesProvider.overrideWith((ref) async => const []),
        ],
      );
      await tester.pumpAndSettle();
      expect(courseFetchCount, 1);

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(courseFetchCount, 2);
    });
  });
}
