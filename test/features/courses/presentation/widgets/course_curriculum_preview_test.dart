import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/design_system/design_system.dart';
import 'package:app/features/courses/domain/entities/course.dart';
import 'package:app/features/courses/domain/entities/lesson.dart';
import 'package:app/features/courses/domain/entities/section.dart';
import 'package:app/features/courses/presentation/widgets/course_curriculum_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _previewLesson = Lesson(
  id: 'lesson-1',
  sectionId: 'section-1',
  title: 'Intro to Widgets',
  isPreview: true,
);

const _lockedLesson = Lesson(
  id: 'lesson-2',
  sectionId: 'section-1',
  title: 'Advanced State Management',
);

const _section = Section(
  id: 'section-1',
  courseId: 'course-1',
  tenantId: 'tenant-1',
  title: 'Getting Started',
  lessons: [_previewLesson, _lockedLesson],
);

const _courseWithCurriculum = Course(
  id: 'course-1',
  tenantId: 'tenant-1',
  title: 'Flutter Mastery',
  status: 'published',
  sections: [_section],
);

const _courseWithoutSections = Course(
  id: 'course-2',
  tenantId: 'tenant-1',
  title: 'No Curriculum Yet',
  status: 'published',
);

Widget _wrap(Course course) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: CourseCurriculumPreview(
            course: course,
            ds: AppColors.of(context),
            l10n: AppLocalizations.of(context)!,
          ),
        ),
      ),
      GoRoute(
        path: '/courses/:courseId/lesson/:lessonId',
        builder: (_, state) => Scaffold(
          body: Text(
            'lesson-${state.pathParameters['courseId']}-${state.pathParameters['lessonId']}',
          ),
        ),
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
  group('CourseCurriculumPreview', () {
    testWidgets('renders nothing when the course has no sections', (tester) async {
      await tester.pumpWidget(_wrap(_courseWithoutSections));

      expect(find.byType(ExpansionTile), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the section title and lesson rows once expanded', (tester) async {
      await tester.pumpWidget(_wrap(_courseWithCurriculum));

      expect(find.text('Getting Started'), findsOneWidget);
      await tester.tap(find.text('Getting Started'));
      await tester.pumpAndSettle();

      expect(find.text('Intro to Widgets'), findsOneWidget);
      expect(find.text('Advanced State Management'), findsOneWidget);
    });

    testWidgets('marks a preview lesson with a play icon and a free badge', (tester) async {
      await tester.pumpWidget(_wrap(_courseWithCurriculum));
      await tester.tap(find.text('Getting Started'));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.freeLabel), findsOneWidget); // only the preview lesson
      expect(find.byIcon(Icons.play_circle_fill_rounded), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget); // the locked one
    });

    testWidgets('tapping a preview lesson navigates to its lesson route', (tester) async {
      await tester.pumpWidget(_wrap(_courseWithCurriculum));
      await tester.tap(find.text('Getting Started'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Intro to Widgets'));
      await tester.pumpAndSettle();

      expect(find.text('lesson-course-1-lesson-1'), findsOneWidget);
    });

    testWidgets('a locked (non-preview) lesson is not tappable', (tester) async {
      await tester.pumpWidget(_wrap(_courseWithCurriculum));
      await tester.tap(find.text('Getting Started'));
      await tester.pumpAndSettle();

      final inkWell = tester.widget<InkWell>(
        find.ancestor(
          of: find.text('Advanced State Management'),
          matching: find.byType(InkWell),
        ),
      );
      expect(inkWell.onTap, isNull);
    });
  });
}
