import 'package:app/core/error/failures.dart';
import 'package:app/core/feature_flags/feature_flag_keys.dart';
import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/auth/application/providers/auth_provider.dart';
import 'package:app/features/courses/application/providers/courses_provider.dart';
import 'package:app/features/courses/domain/repositories/courses_repository.dart';
import 'package:app/features/courses/presentation/widgets/sections_accordion.dart';
import 'package:app/shared/models/lesson.dart';
import 'package:app/shared/models/section.dart';
import 'package:app/shared/utils/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../helpers/feature_flag_overrides.dart';

// Deliberately scoped to what this widget owns directly: rendering, the
// enrollment gate on lesson tap, and the optimistic watched-toggle +
// revert-on-server-failure path (Section 6/14: no silent catch, no raw
// exception leaked to the UI). The download flow this widget also kicks
// off (_handleDownload -> quality selector -> LessonDownloadsGateway) is
// deliberately NOT exercised here — it duplicates the surface already
// owned by the downloads-subsystem test suite, and pulling it in would
// mean stubbing download-remote-datasource/quality-selector machinery
// this file has no real responsibility for validating.

class MockCoursesRepository extends Mock implements CoursesRepository {}

const _previewLesson = Lesson(
  id: 'lesson-preview',
  sectionId: 'section-1',
  title: 'Intro (free preview)',
  isPreview: true,
);

const _lockedLesson = Lesson(
  id: 'lesson-locked',
  sectionId: 'section-1',
  title: 'Advanced Topic',
);

const _section = Section(
  id: 'section-1',
  courseId: 'course-1',
  tenantId: 'tenant-1',
  title: 'Getting Started',
  lessons: [_previewLesson, _lockedLesson],
);

Widget _wrap({
  required CoursesRepository coursesRepository,
  bool isEnrolled = false,
  String currentUserId = 'user-A',
  List<Override> extraOverrides = const [],
}) {
  return ProviderScope(
    overrides: [
      coursesRepositoryProvider.overrideWithValue(coursesRepository),
      // The accordion scopes its local watched/last-watched hints by the
      // signed-in account (Phase 9); tests bind a fixed account id here.
      currentUserIdProvider.overrideWithValue(currentUserId),
      ...extraOverrides,
    ],
    child: MaterialApp(
      scaffoldMessengerKey: FeedbackService.messengerKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SectionsAccordion(
          section: _section,
          courseId: 'course-1',
          courseTitle: 'Flutter Mastery',
          isEnrolled: isEnrolled,
        ),
      ),
    ),
  );
}

void main() {
  late MockCoursesRepository coursesRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    coursesRepository = MockCoursesRepository();
  });

  group('SectionsAccordion — rendering', () {
    testWidgets('shows the section title, lesson count, and expands to show lessons',
        (tester) async {
      await tester.pumpWidget(
        _wrap(coursesRepository: coursesRepository),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text('Getting Started'), findsOneWidget);
      expect(find.text(l10n.lessonsCount(2)), findsOneWidget);

      await tester.tap(find.text('Getting Started'));
      await tester.pumpAndSettle();

      expect(find.text('Intro (free preview)'), findsOneWidget);
      expect(find.text('Advanced Topic'), findsOneWidget);
    });

    testWidgets('a locked lesson (unenrolled, non-preview) has no checkbox, only a lock icon',
        (tester) async {
      await tester.pumpWidget(
        _wrap(coursesRepository: coursesRepository),
      );
      await tester.tap(find.text('Getting Started'));
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsOneWidget); // only the preview lesson's
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    });
  });

  group('SectionsAccordion — enrollment gate', () {
    testWidgets(
        'tapping a locked lesson while unenrolled shows the enrollment-required '
        'dialog and never touches progress or watched status', (tester) async {
      await tester.pumpWidget(
        _wrap(coursesRepository: coursesRepository),
      );
      await tester.tap(find.text('Getting Started'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Advanced Topic'));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.enrollmentRequired), findsOneWidget);
      verifyNever(
        () => coursesRepository.updateLessonProgress(
          courseId: any(named: 'courseId'),
          lessonId: any(named: 'lessonId'),
          completed: any(named: 'completed'),
          progressPct: any(named: 'progressPct'),
          watchTimeSec: any(named: 'watchTimeSec'),
        ),
      );
    });

    testWidgets(
        'tapping a preview lesson while unenrolled opens the player choice '
        'sheet but does NOT mark the lesson watched (Phase 10 BLOCKER fix: '
        'tap-to-open must never write completed=true/100% to the server)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(coursesRepository: coursesRepository),
      );
      await tester.tap(find.text('Getting Started'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Intro (free preview)'));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.enrollmentRequired), findsNothing);
      verifyNever(
        () => coursesRepository.updateLessonProgress(
          courseId: any(named: 'courseId'),
          lessonId: any(named: 'lessonId'),
          completed: any(named: 'completed'),
          progressPct: any(named: 'progressPct'),
          watchTimeSec: any(named: 'watchTimeSec'),
        ),
      );
      // "choose a player" bottom sheet content.
      expect(find.text(l10n.directPlayer), findsOneWidget);
    });
  });

  group('SectionsAccordion — player kill-switch wiring', () {
    testWidgets(
        'the youtube/modern kill switches reach the choice sheet: tapping a '
        'preview lesson offers only the remaining (direct) player', (
      tester,
    ) async {
      when(
        () => coursesRepository.updateLessonProgress(
          courseId: any(named: 'courseId'),
          lessonId: any(named: 'lessonId'),
          completed: any(named: 'completed'),
          progressPct: any(named: 'progressPct'),
          watchTimeSec: any(named: 'watchTimeSec'),
        ),
      ).thenAnswer((_) async => const Right(null));

      await tester.pumpWidget(
        _wrap(
          coursesRepository: coursesRepository,
          extraOverrides: [
            featureFlagsOverride({
              FeatureFlagKey.playerYoutube: false,
              FeatureFlagKey.playerModern: false,
            }),
          ],
        ),
      );
      await tester.tap(find.text('Getting Started'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Intro (free preview)'));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.youtubePlayer), findsNothing);
      expect(find.text(l10n.modernPlayer), findsNothing);
      expect(find.text(l10n.directPlayer), findsOneWidget);
    });
  });

  group('SectionsAccordion — watched-status toggle', () {
    testWidgets('checking a lesson complete calls updateLessonProgress(completed: true)',
        (tester) async {
      when(
        () => coursesRepository.updateLessonProgress(
          courseId: any(named: 'courseId'),
          lessonId: any(named: 'lessonId'),
          completed: any(named: 'completed'),
          progressPct: any(named: 'progressPct'),
          watchTimeSec: any(named: 'watchTimeSec'),
        ),
      ).thenAnswer((_) async => const Right(null));

      await tester.pumpWidget(
        _wrap(
          coursesRepository: coursesRepository,
          isEnrolled: true,
        ),
      );
      await tester.tap(find.text('Getting Started'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      verify(
        () => coursesRepository.updateLessonProgress(
          courseId: 'course-1',
          lessonId: 'lesson-preview',
          completed: true,
          progressPct: 100.0,
          watchTimeSec: any(named: 'watchTimeSec'),
        ),
      ).called(1);
      expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, true);
    });

    testWidgets(
        'a failed server update reverts the optimistic checkbox state and shows a '
        'safe, localized error (never the raw failure.message)', (tester) async {
      when(
        () => coursesRepository.updateLessonProgress(
          courseId: any(named: 'courseId'),
          lessonId: any(named: 'lessonId'),
          completed: any(named: 'completed'),
          progressPct: any(named: 'progressPct'),
          watchTimeSec: any(named: 'watchTimeSec'),
        ),
      ).thenAnswer(
        (_) async => const Left(
          ServerFailure('internal diagnostic: pg constraint 23505'),
        ),
      );

      await tester.pumpWidget(
        _wrap(
          coursesRepository: coursesRepository,
          isEnrolled: true,
        ),
      );
      await tester.tap(find.text('Getting Started'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        find.text('internal diagnostic: pg constraint 23505'),
        findsNothing,
        reason: 'the raw Failure.message must never reach a user-facing snackbar',
      );
      expect(find.text(l10n.errorGeneric), findsOneWidget);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).value,
        false,
        reason: 'the optimistic "completed" update must be reverted on failure',
      );
    });
  });

  // Phase 9 account isolation: local watched hints persist across an app
  // kill or a passive revocation (neither runs the logout prefs wipe). They
  // are keyed by the signed-in account, so the NEXT account must never see
  // them rendered as its own completion state.
  group('SectionsAccordion — local watched hints account isolation', () {
    testWidgets(
        "user A's locally persisted watched hint renders for A, and never "
        'for user B on the same device',
        (tester) async {
      when(
        () => coursesRepository.updateLessonProgress(
          courseId: any(named: 'courseId'),
          lessonId: any(named: 'lessonId'),
          completed: any(named: 'completed'),
          progressPct: any(named: 'progressPct'),
          watchTimeSec: any(named: 'watchTimeSec'),
        ),
      ).thenAnswer((_) async => const Right(null));

      // Simulate user A's device state left behind by an app kill: the
      // preview lesson flagged watched under A's account key, with NO
      // server-side progress for it.
      SharedPreferences.setMockInitialValues({
        'watched_lesson_user-A_lesson-preview': true,
      });

      // Account A: the local hint is honored as an optimistic completion.
      await tester.pumpWidget(
        _wrap(coursesRepository: coursesRepository, isEnrolled: true),
      );
      await tester.tap(find.text('Getting Started'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).value,
        true,
        reason: "A's own persisted hint must still apply to A",
      );

      // Account B signs in on the same device WITHOUT a manual logout in
      // between (passive revocation / app kill path). B's key is empty, so
      // the accordion must show server truth only: unchecked. The blank
      // pump in between forces a full remount — reusing the element tree
      // in place would keep the previous scope's provider state and the
      // already-expanded tile, which is a test artifact, not app behavior.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _wrap(
          coursesRepository: coursesRepository,
          isEnrolled: true,
          currentUserId: 'user-B',
        ),
      );
      await tester.tap(find.text('Getting Started'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).value,
        false,
        reason:
            "B must not inherit A's local watched hint — this is the "
            'cross-account leak fixed in Phase 9',
      );
    });

    testWidgets(
        "user A's last-watched resume pointer is not visible to user B",
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'last_watched_lesson_user-A_0': 'lesson-preview',
      });

      await tester.pumpWidget(
        _wrap(
          coursesRepository: coursesRepository,
          isEnrolled: true,
          currentUserId: 'user-B',
        ),
      );
      await tester.tap(find.text('Getting Started'));
      await tester.pumpAndSettle();

      // No assertion on rendering position needed: the pointer is loaded
      // into state under B's (empty) key. Tapping the preview lesson writes
      // B's own pointer; A's key must remain untouched below. (Phase 10:
      // tapping no longer also writes server progress — the resume pointer
      // is a local hint, deliberately untouched by that fix.)
      await tester.tap(find.text('Intro (free preview)'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      // The fixture's course id ('course-1') is not numeric, so both the
      // writer and course_details_screen's reader map it through
      // int.tryParse(...) ?? 0 — the per-fixture key suffix is '0'.
      expect(prefs.getString('last_watched_lesson_user-B_0'),
          'lesson-preview',
          reason: "B's tap must persist B's own resume pointer");
      expect(prefs.getString('last_watched_lesson_user-A_0'),
          'lesson-preview',
          reason: "B's session writing its own pointer must not clobber A's");
    });
  });
}
