import 'package:app/core/error/failures.dart';
import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/courses/application/providers/courses_provider.dart';
import 'package:app/features/courses/domain/entities/lesson.dart';
import 'package:app/features/courses/domain/entities/section.dart';
import 'package:app/features/courses/domain/repositories/courses_repository.dart';
import 'package:app/features/courses/presentation/widgets/sections_accordion.dart';
import 'package:app/features/downloads/application/providers/downloads_provider.dart';
import 'package:app/features/downloads/domain/repositories/download_repository.dart';
import 'package:app/shared/utils/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Deliberately scoped to what this widget owns directly: rendering, the
// enrollment gate on lesson tap, and the optimistic watched-toggle +
// revert-on-server-failure path (Section 6/14: no silent catch, no raw
// exception leaked to the UI). The download flow this widget also kicks
// off (_handleDownload -> quality selector -> downloadsProvider) is
// deliberately NOT exercised here — it duplicates the surface already
// owned by the downloads-subsystem test suite, and pulling it in would
// mean stubbing download-remote-datasource/quality-selector machinery
// this file has no real responsibility for validating.

class MockCoursesRepository extends Mock implements CoursesRepository {}

class MockDownloadRepository extends Mock implements DownloadRepository {}

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
  required DownloadRepository downloadRepository,
  bool isEnrolled = false,
}) {
  return ProviderScope(
    overrides: [
      coursesRepositoryProvider.overrideWithValue(coursesRepository),
      downloadRepositoryProvider.overrideWithValue(downloadRepository),
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
  late MockDownloadRepository downloadRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    coursesRepository = MockCoursesRepository();
    downloadRepository = MockDownloadRepository();
    when(() => downloadRepository.getDownloads())
        .thenAnswer((_) async => const Right([]));
    when(() => downloadRepository.changeStream)
        .thenAnswer((_) => const Stream.empty());
  });

  group('SectionsAccordion — rendering', () {
    testWidgets('shows the section title, lesson count, and expands to show lessons',
        (tester) async {
      await tester.pumpWidget(
        _wrap(coursesRepository: coursesRepository, downloadRepository: downloadRepository),
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
        _wrap(coursesRepository: coursesRepository, downloadRepository: downloadRepository),
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
        _wrap(coursesRepository: coursesRepository, downloadRepository: downloadRepository),
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
        'tapping a preview lesson while unenrolled is allowed straight through '
        '(marks watched + opens the player choice sheet), no enrollment dialog',
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
        _wrap(coursesRepository: coursesRepository, downloadRepository: downloadRepository),
      );
      await tester.tap(find.text('Getting Started'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Intro (free preview)'));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.enrollmentRequired), findsNothing);
      verify(
        () => coursesRepository.updateLessonProgress(
          courseId: 'course-1',
          lessonId: 'lesson-preview',
          completed: true,
          progressPct: 100.0,
          watchTimeSec: any(named: 'watchTimeSec'),
        ),
      ).called(1);
      // "choose a player" bottom sheet content.
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
          downloadRepository: downloadRepository,
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
          downloadRepository: downloadRepository,
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
}
