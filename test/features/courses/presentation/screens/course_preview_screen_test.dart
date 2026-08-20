import 'dart:async';

import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/core/logging/infrastructure/event_bus.dart';
import 'package:app/core/logging/logging_providers.dart';
import 'package:app/features/auth/domain/entities/auth_state.dart';
import 'package:app/features/courses/application/providers/courses_provider.dart';
import 'package:app/features/courses/domain/entities/course.dart';
import 'package:app/features/courses/domain/entities/lesson.dart';
import 'package:app/features/courses/domain/entities/section.dart';
import 'package:app/features/courses/presentation/screens/course_preview_screen.dart';
import 'package:app/shared/cross_feature/auth_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../widgets/course_widget_test_helpers.dart';

class MockEventBus extends Mock implements EventBus {}

class _FakeAuthNotifier extends Auth {
  @override
  AuthState build() => const AuthUnauthenticated();
}

class _MockBookmarks extends BookmarkedCourses {
  @override
  Future<Set<String>> build() async => <String>{};

  @override
  Future<void> toggleBookmark(String courseId) async {}
}

const tCourseWithSections = Course(
  id: 'course-1',
  tenantId: 'tenant-1',
  title: 'Flutter for Beginners',
  description: 'Learn Flutter from scratch, step by step.',
  status: 'published',
  price: 49.99,
  isFree: false,
  sections: [
    Section(
      id: 'sec-1',
      courseId: 'course-1',
      tenantId: 'tenant-1',
      title: 'Introduction to Flutter',
      lessons: [
        Lesson(
          id: 'les-1',
          sectionId: 'sec-1',
          tenantId: 'tenant-1',
          title: 'Welcome & Overview',
          durationSec: 600,
          isPreview: true,
        ),
      ],
    ),
  ],
);

Future<void> pumpCoursePreview(
  WidgetTester tester, {
  required String courseId,
  required List<Override> overrides,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(() => _FakeAuthNotifier()),
        eventBusProvider.overrideWithValue(MockEventBus()),
        bookmarkedCoursesProvider.overrideWith(() => _MockBookmarks()),
        ...overrides,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CoursePreviewScreen(courseId: courseId),
      ),
    ),
  );
}

void main() {
  group('CoursePreviewScreen — ticker and animation sanity', () {
    testWidgets('renders without throwing multiple tickers exception',
        (tester) async {
      await pumpCoursePreview(
        tester,
        courseId: tFullCourse.id,
        overrides: [
          courseDetailsProvider(tFullCourse.id)
              .overrideWith((ref) async => tFullCourse),
          myCoursesProvider.overrideWith((ref) async => const []),
        ],
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(tFullCourse.title), findsWidgets);
    });
  });

  group('CoursePreviewScreen — loading state', () {
    testWidgets('shows skeleton content while course is loading',
        (tester) async {
      await pumpCoursePreview(
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

  group('CoursePreviewScreen — error state', () {
    testWidgets('shows error state when course fetch fails',
        (tester) async {
      await pumpCoursePreview(
        tester,
        courseId: 'course-err',
        overrides: [
          courseDetailsProvider('course-err').overrideWith((ref) async {
            throw Exception('network unreachable');
          }),
          myCoursesProvider.overrideWith((ref) async => const []),
        ],
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });
  });

  group('CoursePreviewScreen — tabs and content', () {
    testWidgets('switches between description and curriculum tabs',
        (tester) async {
      await pumpCoursePreview(
        tester,
        courseId: tCourseWithSections.id,
        overrides: [
          courseDetailsProvider(tCourseWithSections.id)
              .overrideWith((ref) async => tCourseWithSections),
          myCoursesProvider.overrideWith((ref) async => const []),
        ],
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // Initial tab is Description (index 0)
      expect(find.text(tCourseWithSections.description!), findsOneWidget);

      // Switch to Curriculum tab
      await tester.tap(find.text(l10n.courseCurriculumLabel));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Introduction to Flutter'), findsOneWidget);

      // Switch back to Description tab
      await tester.tap(find.text(l10n.courseDescriptionLabel));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(tCourseWithSections.description!), findsOneWidget);
    });
  });
}
