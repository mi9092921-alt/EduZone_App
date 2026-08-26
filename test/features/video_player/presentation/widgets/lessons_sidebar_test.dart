import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/courses/application/providers/courses_provider.dart';
import 'package:app/features/courses/domain/entities/course.dart';
import 'package:app/features/courses/domain/entities/course_enrollment.dart';
import 'package:app/features/courses/domain/entities/lesson.dart';
import 'package:app/features/courses/domain/entities/section.dart';
import 'package:app/features/courses/domain/repositories/courses_repository.dart';
import 'package:app/features/video_player/presentation/widgets/lessons_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

// Regression coverage for the lock icon that always rendered in the video
// player's lesson sidebar (`lib/shared/components/lesson_tile.dart`'s
// `Icons.lock_outline_rounded`), even for lessons an enrolled user could
// legitimately access.
//
// Root cause: `LessonsSidebar` used to derive both `isEnrolled` and
// `isLocked` from `Lesson.hasAccess`. That field is documented (see
// `Lesson.hasAccess`'s doc comment) as "populated by the
// get_course_lessons_with_access RPC" -- but nothing in this app calls that
// RPC. The only datasource that actually feeds this screen,
// `CoursesRemoteDataSourceImpl.getCourseOutline()`, queries `lessons`
// directly via PostgREST and never returns a `has_access` key, so
// `Lesson.hasAccess` silently defaults to `false` for every lesson on every
// real course payload. `SectionsAccordion` (the courses-feature equivalent)
// never had this bug because it takes `isEnrolled` as an explicit
// caller-supplied parameter backed by `isEnrolledProvider`; this suite
// deliberately never sets `hasAccess: true` on any fixture, to match what
// production payloads actually look like, and asserts the sidebar now
// follows the same `isEnrolledProvider` pattern instead.

class MockCoursesRepository extends Mock implements CoursesRepository {}

const _courseId = 'course-1';
const _previewLessonId = 'lesson-preview';
const _lockedLessonId = 'lesson-locked';

const _course = Course(
  id: _courseId,
  tenantId: 'tenant-1',
  title: 'Flutter Mastery',
  status: 'published',
  sections: [
    Section(
      id: 'section-1',
      courseId: _courseId,
      tenantId: 'tenant-1',
      title: 'Getting Started',
      lessons: [
        // Deliberately no `hasAccess:` override -- defaults to `false`,
        // exactly like every real Lesson built from getCourseOutline().
        Lesson(
          id: _previewLessonId,
          sectionId: 'section-1',
          courseId: _courseId,
          title: 'Intro (free preview)',
          isPreview: true,
        ),
        Lesson(
          id: _lockedLessonId,
          sectionId: 'section-1',
          courseId: _courseId,
          title: 'Advanced Topic',
        ),
      ],
    ),
  ],
);

Widget _wrap({
  required CoursesRepository coursesRepository,
  String currentLessonId = _lockedLessonId,
}) {
  return ProviderScope(
    overrides: [coursesRepositoryProvider.overrideWithValue(coursesRepository)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: LessonsSidebar(
          course: _course,
          currentLessonId: currentLessonId,
          onLessonTap: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  late MockCoursesRepository coursesRepository;

  setUp(() {
    coursesRepository = MockCoursesRepository();
  });

  group('LessonsSidebar — lock state (regression for always-locked bug)', () {
    testWidgets(
        'an enrolled user sees NO lock icon on a non-preview lesson, even '
        'though Lesson.hasAccess is never populated by the real course-outline '
        'payload', (tester) async {
      when(() => coursesRepository.getMyCourses()).thenAnswer(
        (_) async => const Right([
          CourseEnrollment(
            id: 'enrollment-1',
            userId: 'user-1',
            courseId: _courseId,
            tenantId: 'tenant-1',
          ),
        ]),
      );

      await tester.pumpWidget(_wrap(coursesRepository: coursesRepository));
      await tester.pumpAndSettle();

      expect(find.text('Advanced Topic'), findsOneWidget);
      expect(
        find.byIcon(Icons.lock_outline_rounded),
        findsNothing,
        reason: 'enrolled users must not see a lock on a lesson they have access to',
      );
      expect(find.byType(Checkbox), findsWidgets);
    });

    testWidgets(
        'an unenrolled user still sees the lock icon on a non-preview lesson',
        (tester) async {
      when(() => coursesRepository.getMyCourses())
          .thenAnswer((_) async => const Right([]));

      await tester.pumpWidget(_wrap(coursesRepository: coursesRepository));
      await tester.pumpAndSettle();

      expect(find.text('Advanced Topic'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    });

    testWidgets('a preview lesson is never locked, enrolled or not',
        (tester) async {
      when(() => coursesRepository.getMyCourses())
          .thenAnswer((_) async => const Right([]));

      await tester.pumpWidget(
        _wrap(
          coursesRepository: coursesRepository,
          currentLessonId: _previewLessonId,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Intro (free preview)'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
    });
  });
}
