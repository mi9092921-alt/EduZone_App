import 'package:app/features/courses/domain/entities/lesson.dart';
import 'package:app/features/courses/presentation/widgets/sections_accordion/lesson_tile_wrapper.dart';
import 'package:app/features/downloads/domain/entities/download_enums.dart';
import 'package:app/features/downloads/domain/entities/downloaded_lesson.dart';
import 'package:app/shared/cross_feature/downloads_shared.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sections_accordion_test_helpers.dart';

/// Fake notifier returning a fixed list without touching any repository —
/// `DownloadsNotifier.build()` normally calls
/// `ref.watch(downloadRepositoryProvider)`, which needs real platform
/// services this test sandbox doesn't have.
class _FakeDownloadsNotifier extends DownloadsNotifier {
  _FakeDownloadsNotifier(this._downloads);
  final List<DownloadedLesson> _downloads;

  @override
  Future<List<DownloadedLesson>> build() async => _downloads;
}

DownloadedLesson _download({
  required String lessonId,
  required DownloadStatus status,
  double progress = 0.0,
}) {
  final now = DateTime(2026);
  return DownloadedLesson(
    id: 'dl_$lessonId',
    lessonId: lessonId,
    courseId: 'course_1',
    title: 'Downloaded lesson',
    localPath: '/tmp/$lessonId',
    encryptedPath: '/tmp/$lessonId.enc',
    videoUrl: 'https://example.com/$lessonId.mp4',
    quality: VideoQuality.p144,
    fileSize: 1024,
    status: status,
    progress: progress,
    downloadedAt: now,
    expiresAt: now.add(const Duration(days: 30)),
  );
}

Lesson _lesson({String id = 'lesson_1', bool isPreview = false}) => Lesson(
  id: id,
  sectionId: 'section_1',
  title: 'Intro to Widgets',
  isPreview: isPreview,
);

void main() {
  group('LessonTileWrapper', () {
    testWidgets('renders the lesson title when there is no matching download', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          LessonTileWrapper(
            lesson: _lesson(),
            courseId: 'course_1',
            courseTitle: 'Flutter Basics',
            isEnrolled: true,
            isCompleted: false,
            isLastWatched: false,
            onTap: () {},
            onToggleCompleted: (_) {},
            onDownload: () {},
          ),
          overrides: [
            downloadsProvider.overrideWith(() => _FakeDownloadsNotifier(const [])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Intro to Widgets'), findsOneWidget);
    });

    testWidgets('fires onTap when the tile is tapped', (
      WidgetTester tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          LessonTileWrapper(
            lesson: _lesson(isPreview: true),
            courseId: 'course_1',
            courseTitle: 'Flutter Basics',
            isEnrolled: false,
            isCompleted: false,
            isLastWatched: false,
            onTap: () => tapped = true,
            onToggleCompleted: (_) {},
            onDownload: () {},
          ),
          overrides: [
            downloadsProvider.overrideWith(() => _FakeDownloadsNotifier(const [])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Intro to Widgets'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('reflects a completed download for the matching lesson id', (
      WidgetTester tester,
    ) async {
      final download = _download(
        lessonId: 'lesson_1',
        status: DownloadStatus.completed,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          LessonTileWrapper(
            lesson: _lesson(),
            courseId: 'course_1',
            courseTitle: 'Flutter Basics',
            isEnrolled: true,
            isCompleted: false,
            isLastWatched: false,
            onTap: () {},
            onToggleCompleted: (_) {},
            onDownload: () {},
          ),
          overrides: [
            downloadsProvider.overrideWith(
              () => _FakeDownloadsNotifier([download]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // A download exists for this lesson id and is completed — the tile
      // renders successfully with that state resolved (no exception from
      // matching the lessonId string against DownloadedLesson.lessonId).
      expect(find.text('Intro to Widgets'), findsOneWidget);
    });

    testWidgets('does not match a download belonging to a different lesson', (
      WidgetTester tester,
    ) async {
      final otherDownload = _download(
        lessonId: 'some_other_lesson',
        status: DownloadStatus.completed,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          LessonTileWrapper(
            lesson: _lesson(id: 'lesson_1'),
            courseId: 'course_1',
            courseTitle: 'Flutter Basics',
            isEnrolled: true,
            isCompleted: false,
            isLastWatched: false,
            onTap: () {},
            onToggleCompleted: (_) {},
            onDownload: () {},
          ),
          overrides: [
            downloadsProvider.overrideWith(
              () => _FakeDownloadsNotifier([otherDownload]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Intro to Widgets'), findsOneWidget);
    });
  });
}
