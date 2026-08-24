import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/courses/domain/entities/course.dart';
import 'package:app/features/courses/domain/entities/course_enrollment.dart';
import 'package:app/features/courses/presentation/widgets/my_courses_preview.dart';
import 'package:app/shared/components/course_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => Scaffold(body: child)),
      GoRoute(
        path: '/courses/:id',
        builder: (_, state) =>
            Scaffold(body: Text('course-${state.pathParameters['id']}')),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  group('MyCoursesPreview', () {
    testWidgets('shows a shimmer while isLoading is true, regardless of enrollment', (tester) async {
      const enrollment = CourseEnrollment(
        id: 'e1',
        userId: 'u1',
        courseId: 'c1',
        tenantId: 't1',
        course: Course(id: 'c1', tenantId: 't1', title: 'X', status: 'published'),
      );

      await tester.pumpWidget(
        _wrap(const MyCoursesPreview(enrollment: enrollment, isLoading: true)),
      );

      expect(find.byType(MyCourseCardShimmer), findsOneWidget);
      expect(find.text('X'), findsNothing);
    });

    testWidgets('shows a shimmer when there is no enrollment yet', (tester) async {
      await tester.pumpWidget(_wrap(const MyCoursesPreview()));

      expect(find.byType(MyCourseCardShimmer), findsOneWidget);
    });

    testWidgets(
        'renders nothing (not a crash) when the enrollment has no embedded '
        'course', (tester) async {
      const enrollment = CourseEnrollment(
        id: 'e1',
        userId: 'u1',
        courseId: 'c1',
        tenantId: 't1',
        // course: null (not embedded — e.g. a partial/optimistic entry)
      );

      await tester.pumpWidget(_wrap(const MyCoursesPreview(enrollment: enrollment)));

      expect(find.byType(MyCourseCardShimmer), findsNothing);
      expect(find.byType(MyCourseCard), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        "prefers the enrollment's own totalLessons over the course's when "
        'it is a positive number', (tester) async {
      const course = Course(
        id: 'c1',
        tenantId: 't1',
        title: 'Flutter Mastery',
        status: 'published',
        totalLessons: 20,
      );
      const enrollment = CourseEnrollment(
        id: 'e1',
        userId: 'u1',
        courseId: 'c1',
        tenantId: 't1',
        course: course,
        totalLessons: 7, // enrollment-scoped count should win
        progressPct: 50,
      );

      await tester.pumpWidget(_wrap(const MyCoursesPreview(enrollment: enrollment)));

      final card = tester.widget<MyCourseCard>(find.byType(MyCourseCard));
      expect(card.data.totalLessons, 7);
      expect(card.data.progress, 0.5); // progressPct / 100.0
      expect(find.text('Flutter Mastery'), findsOneWidget);
    });

    testWidgets(
        "falls back to the course's own lesson count when the enrollment's "
        'totalLessons is not positive (0/unset)', (tester) async {
      const course = Course(
        id: 'c1',
        tenantId: 't1',
        title: 'Flutter Mastery',
        status: 'published',
        totalLessons: 20,
      );
      const enrollment = CourseEnrollment(
        id: 'e1',
        userId: 'u1',
        courseId: 'c1',
        tenantId: 't1',
        course: course,
      );

      await tester.pumpWidget(_wrap(const MyCoursesPreview(enrollment: enrollment)));

      final card = tester.widget<MyCourseCard>(find.byType(MyCourseCard));
      expect(card.data.totalLessons, 20);
    });

    testWidgets('tapping the card navigates to /courses/:id', (tester) async {
      const course = Course(
        id: 'c1',
        tenantId: 't1',
        title: 'Flutter Mastery',
        status: 'published',
      );
      const enrollment = CourseEnrollment(
        id: 'e1',
        userId: 'u1',
        courseId: 'c1',
        tenantId: 't1',
        course: course,
      );

      await tester.pumpWidget(_wrap(const MyCoursesPreview(enrollment: enrollment)));
      await tester.tap(find.text('Flutter Mastery'));
      await tester.pumpAndSettle();

      expect(find.text('course-c1'), findsOneWidget);
    });
  });
}
