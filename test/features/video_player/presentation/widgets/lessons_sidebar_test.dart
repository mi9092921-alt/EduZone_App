import 'package:app/core/feature_flags/feature_flag_keys.dart';
import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/video_player/presentation/widgets/lessons_sidebar.dart';
import 'package:app/shared/components/lesson_tile.dart';
import 'package:app/shared/models/course.dart';
import 'package:app/shared/models/lesson.dart';
import 'package:app/shared/models/section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/feature_flag_overrides.dart';

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
// caller-supplied parameter; this suite deliberately never sets
// `hasAccess: true` on any fixture, to match what production payloads
// actually look like, and asserts the sidebar follows the same
// caller-supplied-`isEnrolled` pattern (resolved by the route composition
// layer from the courses feature's `isEnrolledProvider`).

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
  required bool isEnrolled,
  String currentLessonId = _lockedLessonId,
  Map<FeatureFlagKey, bool> flagValues = const {},
}) {
  return ProviderScope(
    overrides: [featureFlagsOverride(flagValues)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: LessonsSidebar(
          course: _course,
          currentLessonId: currentLessonId,
          isEnrolled: isEnrolled,
          onLessonTap: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  group('LessonsSidebar — lock state (regression for always-locked bug)', () {
    testWidgets(
        'an enrolled user sees NO lock icon on a non-preview lesson, even '
        'though Lesson.hasAccess is never populated by the real course-outline '
        'payload', (tester) async {
      await tester.pumpWidget(_wrap(isEnrolled: true));
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
      await tester.pumpWidget(_wrap(isEnrolled: false));
      await tester.pumpAndSettle();

      expect(find.text('Advanced Topic'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    });

    testWidgets('a preview lesson is never locked, enrolled or not',
        (tester) async {
      await tester.pumpWidget(
        _wrap(isEnrolled: false, currentLessonId: _previewLessonId),
      );
      await tester.pumpAndSettle();

      final previewTile = find.ancestor(
        of: find.text('Intro (free preview)'),
        matching: find.byType(LessonTile),
      );
      expect(
        find.descendant(
          of: previewTile,
          matching: find.byIcon(Icons.lock_outline_rounded),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: previewTile,
          matching: find.byType(Checkbox),
        ),
        findsOneWidget,
      );
    });
  });

  group('LessonsSidebar — courses_downloads kill switch', () {
    testWidgets(
        'the per-lesson download indicator renders for an enrolled user by '
        'default (flag on)', (tester) async {
      await tester.pumpWidget(_wrap(isEnrolled: true));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.download_for_offline_outlined), findsWidgets);
    });

    testWidgets(
        'the download indicator disappears for everyone when '
        'courses_downloads is disabled remotely', (tester) async {
      await tester.pumpWidget(
        _wrap(
          isEnrolled: true,
          flagValues: {FeatureFlagKey.coursesDownloads: false},
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byIcon(Icons.download_for_offline_outlined),
        findsNothing,
        reason:
            'the sidebar was the one LessonTile call site that ignored the '
            'courses_downloads flag — the button must vanish with the rest',
      );
    });
  });
}
