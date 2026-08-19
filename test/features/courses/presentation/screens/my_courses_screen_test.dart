import 'dart:async';

import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/courses/application/providers/courses_provider.dart';
import 'package:app/features/courses/domain/entities/course.dart';
import 'package:app/features/courses/domain/entities/course_enrollment.dart';
import 'package:app/features/courses/presentation/screens/my_courses_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

const _course = Course(
  id: 'course-1',
  tenantId: 'tenant-1',
  title: 'Flutter for Beginners',
  status: 'published',
);

CourseEnrollment _enrollment({
  required String id,
  Course course = _course,
  double progressPct = 25,
}) {
  return CourseEnrollment(
    id: id,
    userId: 'user-1',
    courseId: course.id,
    tenantId: 'tenant-1',
    progressPct: progressPct,
    course: course,
  );
}

Future<void> pumpMyCourses(
  WidgetTester tester, {
  required List<Override> overrides,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MyCoursesScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('shows a loading skeleton while enrollments are fetching', (
    tester,
  ) async {
    await pumpMyCourses(
      tester,
      overrides: [
        myCoursesProvider.overrideWith(
          (ref) => Completer<List<CourseEnrollment>>().future,
        ),
      ],
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.coursesTab), findsOneWidget);
  });

  testWidgets('shows the empty state when the user has no enrollments', (
    tester,
  ) async {
    await pumpMyCourses(
      tester,
      overrides: [myCoursesProvider.overrideWith((ref) async => const [])],
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.no_courses_available), findsOneWidget);
  });

  testWidgets('renders a card for each enrolled course', (tester) async {
    final courseB = _course.copyWith(id: 'course-2', title: 'Advanced Dart');

    await pumpMyCourses(
      tester,
      overrides: [
        myCoursesProvider.overrideWith(
          (ref) async => [
            _enrollment(id: 'e1'),
            _enrollment(id: 'e2', course: courseB),
          ],
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text(_course.title), findsOneWidget);
    expect(find.text(courseB.title), findsOneWidget);
  });

  testWidgets(
      'renders nothing for an enrollment whose joined course failed to '
      'load (course == null) instead of crashing', (tester) async {
    const incompleteEnrollment = CourseEnrollment(
      id: 'e-broken',
      userId: 'user-1',
      courseId: 'course-missing',
      tenantId: 'tenant-1',
    );

    await pumpMyCourses(
      tester,
      overrides: [
        myCoursesProvider.overrideWith(
          (ref) async => [incompleteEnrollment],
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  group('MyCoursesScreen — error state', () {
    testWidgets(
        'shows a friendly, localized error (not the raw exception) and a '
        'retry action that re-invalidates myCoursesProvider', (tester) async {
      var fetchCount = 0;
      await pumpMyCourses(
        tester,
        overrides: [
          myCoursesProvider.overrideWith((ref) async {
            fetchCount++;
            throw Exception('supabase: connection refused');
          }),
        ],
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.errorGeneric), findsOneWidget);
      expect(find.text(l10n.failedToLoadCourses), findsOneWidget);
      expect(find.text(l10n.retryButton), findsOneWidget);
      // This screen passes a fixed localized string
      // (`l10n.failedToLoadCourses`) into AppScreen's `error` field rather
      // than the caught error at all — like course_details_screen (via
      // ErrorHandler.getMessage) and offline_player_screen (via a fixed
      // string), the raw exception never reaches the UI here.
      expect(find.textContaining('Exception'), findsNothing);
      expect(fetchCount, greaterThanOrEqualTo(1));

      final initialFetchCount = fetchCount;
      await tester.tap(find.text(l10n.retryButton));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(fetchCount, greaterThan(initialFetchCount));
    });
  });

  group('MyCoursesScreen — pull to refresh', () {
    testWidgets('pulling to refresh re-fetches the enrollment list', (
      tester,
    ) async {
      var fetchCount = 0;
      await pumpMyCourses(
        tester,
        overrides: [
          myCoursesProvider.overrideWith((ref) async {
            fetchCount++;
            return const <CourseEnrollment>[];
          }),
        ],
      );
      await tester.pumpAndSettle();
      expect(fetchCount, 1);

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(fetchCount, 2);
    });
  });
}
