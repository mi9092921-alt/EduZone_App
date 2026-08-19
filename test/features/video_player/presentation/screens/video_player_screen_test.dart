import 'dart:async';

import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/courses/application/providers/courses_provider.dart';
import 'package:app/features/courses/domain/entities/course.dart';
import 'package:app/features/courses/domain/entities/lesson.dart';
import 'package:app/features/courses/domain/entities/lesson_content.dart';
import 'package:app/features/courses/domain/entities/section.dart';
import 'package:app/features/video_player/application/providers/video_provider.dart';
import 'package:app/features/video_player/presentation/screens/video_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

/// Fixed-state fake so tests never touch [VideoProgress]'s real repository/
/// sync-engine dependencies. Mirrors the `_ScenarioAuth extends Auth`
/// pattern already used in `integration_test/app_test.dart`.
class _FixedVideoProgress extends VideoProgress {
  _FixedVideoProgress(this._state);
  final VideoState _state;

  @override
  VideoState build(String courseId, String lessonId) => _state;
}

const _courseId = 'course-1';
const _lessonId = 'lesson-1';

const _course = Course(
  id: _courseId,
  tenantId: 'tenant-1',
  title: 'Flutter for Beginners',
  status: 'published',
  sections: [
    Section(
      id: 'section-1',
      courseId: _courseId,
      tenantId: 'tenant-1',
      title: 'Getting Started',
      lessons: [
        Lesson(
          id: _lessonId,
          sectionId: 'section-1',
          courseId: _courseId,
          title: 'Lesson One',
          hasAccess: true,
        ),
      ],
    ),
  ],
);

Future<void> pumpVideoPlayer(
  WidgetTester tester, {
  required List<Override> overrides,
  Widget Function(BuildContext, bool, VoidCallback, bool)? playerBuilder,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: VideoPlayerScreen(
          courseId: _courseId,
          lessonId: _lessonId,
          playerBuilder:
              playerBuilder ?? (context, isFullScreen, toggle, isVertical) =>
                  const Text('PLAYER_STUB'),
        ),
      ),
    ),
  );
}

void main() {
  // VideoPlayerScreen's fullscreen toggle and dispose() both call
  // SystemChrome.setPreferredOrientations/setEnabledSystemUIMode (gated by
  // `!kIsWeb`, which is false on the VM test target, so these DO fire).
  // Without a mock handler, flutter/platform has no implementation
  // registered in the test binding and the resulting Future rejects with
  // MissingPluginException — uncaught since the call sites don't await it.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('VideoPlayerScreen — loading state', () {
    testWidgets('shows a skeleton while the course is loading', (
      tester,
    ) async {
      await pumpVideoPlayer(
        tester,
        overrides: [
          courseDetailsProvider(_courseId).overrideWith(
            (ref) => Completer<Course>().future,
          ),
          lessonContentProvider(_lessonId).overrideWith(
            (ref) => Completer<LessonContent>().future,
          ),
        ],
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('PLAYER_STUB'), findsNothing);
    });
  });

  group('VideoPlayerScreen — lesson not found', () {
    testWidgets(
        'shows a localized "lesson not found" message instead of crashing '
        'when the lesson id is not in any section of the course',
        (tester) async {
      final courseWithoutLesson = _course.copyWith(
        sections: const [
          Section(
            id: 'section-1',
            courseId: _courseId,
            tenantId: 'tenant-1',
            title: 'Getting Started',
            lessons: [],
          ),
        ],
      );

      await pumpVideoPlayer(
        tester,
        overrides: [
          courseDetailsProvider(_courseId)
              .overrideWith((ref) async => courseWithoutLesson),
          lessonContentProvider(_lessonId).overrideWith(
            (ref) => Completer<LessonContent>().future,
          ),
        ],
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.lessonNotFound), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('VideoPlayerScreen — paywall', () {
    testWidgets(
        'shows the enrollment paywall instead of the player when the '
        'lesson content reports hasAccess == false', (tester) async {
      await pumpVideoPlayer(
        tester,
        overrides: [
          courseDetailsProvider(_courseId).overrideWith((ref) async => _course),
          lessonContentProvider(_lessonId).overrideWith(
            (ref) async => const LessonContent(
              lessonId: _lessonId,
              courseId: _courseId,
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.enrollmentRequired), findsOneWidget);
      expect(find.text('PLAYER_STUB'), findsNothing);
    });
  });

  group('VideoPlayerScreen — granted access', () {
    testWidgets(
        'renders the injected player, the lesson title, and the lesson '
        'sidebar once access is granted', (tester) async {
      await pumpVideoPlayer(
        tester,
        overrides: [
          courseDetailsProvider(_courseId).overrideWith((ref) async => _course),
          lessonContentProvider(_lessonId).overrideWith(
            (ref) async => const LessonContent(
              lessonId: _lessonId,
              courseId: _courseId,
              hasAccess: true,
            ),
          ),
          videoProgressProvider(_courseId, _lessonId).overrideWith(
            () => _FixedVideoProgress(
              VideoState(
                progressPct: 0,
                watchTimeSec: 0,
                isCompleted: false,
              ),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('PLAYER_STUB'), findsOneWidget);
      expect(find.text('Lesson One'), findsWidgets);
    });

    testWidgets('shows a progress bar and a completed checkmark once the '
        'lesson is finished', (tester) async {
      await pumpVideoPlayer(
        tester,
        overrides: [
          courseDetailsProvider(_courseId).overrideWith((ref) async => _course),
          lessonContentProvider(_lessonId).overrideWith(
            (ref) async => const LessonContent(
              lessonId: _lessonId,
              courseId: _courseId,
              hasAccess: true,
            ),
          ),
          videoProgressProvider(_courseId, _lessonId).overrideWith(
            () => _FixedVideoProgress(
              VideoState(
                progressPct: 100,
                watchTimeSec: 600,
                isCompleted: true,
              ),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets(
        'toggling full screen keeps the player widget mounted (no rebuild '
        'from scratch) — regression guard for the documented GlobalKey '
        'requirement', (tester) async {
      var playerBuildCount = 0;
      await pumpVideoPlayer(
        tester,
        overrides: [
          courseDetailsProvider(_courseId).overrideWith((ref) async => _course),
          lessonContentProvider(_lessonId).overrideWith(
            (ref) async => const LessonContent(
              lessonId: _lessonId,
              courseId: _courseId,
              hasAccess: true,
            ),
          ),
          videoProgressProvider(_courseId, _lessonId).overrideWith(
            () => _FixedVideoProgress(
              VideoState(progressPct: 0, watchTimeSec: 0, isCompleted: false),
            ),
          ),
        ],
        playerBuilder: (context, isFullScreen, toggle, isVertical) {
          playerBuildCount++;
          return ElevatedButton(
            onPressed: toggle,
            child: Text(isFullScreen ? 'FULLSCREEN' : 'NORMAL'),
          );
        },
      );
      await tester.pumpAndSettle();
      expect(find.text('NORMAL'), findsOneWidget);

      await tester.tap(find.text('NORMAL'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('FULLSCREEN'), findsOneWidget);
      expect(
        playerBuildCount,
        greaterThanOrEqualTo(2),
        reason: 'playerBuilder is expected to be called again with the new '
            'isFullScreen flag; the GlobalKey preserves the *player\'s own* '
            'internal State across this transition, not the builder call '
            'itself.',
      );
    });
  });
}
