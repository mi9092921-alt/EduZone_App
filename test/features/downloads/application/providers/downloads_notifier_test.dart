import 'dart:async';

import 'package:app/core/error/failures.dart';
import 'package:app/features/downloads/application/providers/downloads_provider.dart';
import 'package:app/features/downloads/domain/entities/download_enums.dart';
import 'package:app/features/downloads/domain/entities/download_progress.dart';
import 'package:app/features/downloads/domain/entities/downloaded_lesson.dart';
import 'package:app/features/downloads/domain/repositories/download_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class MockDownloadRepository extends Mock implements DownloadRepository {}

// ─── Fixtures ────────────────────────────────────────────────────────────────

DownloadedLesson _lesson(
  String id, {
  DownloadStatus status = DownloadStatus.completed,
}) {
  return DownloadedLesson(
    id: id,
    lessonId: 'lesson-$id',
    courseId: 'course-1',
    courseTitle: 'Course 1',
    title: 'Lesson $id',
    localPath: '/tmp/$id',
    encryptedPath: '/tmp/$id.enc',
    videoUrl: 'https://example.com/$id.mp4',
    quality: VideoQuality.p720,
    fileSize: 1000,
    status: status,
    downloadedAt: DateTime(2026),
    expiresAt: DateTime(2026, 2),
  );
}

/// Drains pending microtasks so async stream listeners (and the
/// `AsyncValue.guard` they await) have a chance to settle before assertions.
/// Mirrors the pattern already used in auth_notifier_test.dart for the same
/// class of "unawaited async callback" timing issue.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late MockDownloadRepository repository;
  late StreamController<void> changeStreamController;
  late ProviderContainer container;

  setUp(() {
    repository = MockDownloadRepository();
    changeStreamController = StreamController<void>.broadcast();
    when(() => repository.changeStream)
        .thenAnswer((_) => changeStreamController.stream);

    container = ProviderContainer(
      overrides: [
        downloadRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await changeStreamController.close();
  });

  group('DownloadsNotifier.build', () {
    test('loads the initial list of downloads from the repository', () async {
      when(() => repository.getDownloads())
          .thenAnswer((_) async => Right([_lesson('1')]));

      final result = await container.read(downloadsProvider.future);

      expect(result, hasLength(1));
      expect(result.first.id, '1');
      verify(() => repository.getDownloads()).called(1);
    });

    test('a repository failure surfaces as AsyncError on the provider', () async {
      const failure = CacheFailure('db error');
      when(() => repository.getDownloads())
          .thenAnswer((_) async => const Left(failure));

      // NOTE: `expectLater(container.read(downloadsProvider.future),
      // throwsA(...))` deadlocks here — a known Riverpod edge case where a
      // keepAlive AsyncNotifier's very first `build()` throwing, observed
      // via a cold `.future` read with no prior listener, never settles.
      // Establishing a listener first (as any real widget's ref.watch
      // would) and then reading the synchronous state avoids it entirely.
      final sub = container.listen(downloadsProvider, (_, _) {});
      addTearDown(sub.close);

      await _settle();

      final state = container.read(downloadsProvider);
      expect(state.hasError, isTrue);
      expect(state.error, same(failure));
    });

    test(
      'a changeStream event reloads downloads and invalidates storage usage',
      () async {
        when(() => repository.getDownloads())
            .thenAnswer((_) async => Right([_lesson('1')]));
        when(() => repository.getTotalStorageUsed())
            .thenAnswer((_) async => const Right(1024));

        // Pin totalStorageUsedProvider alive with a listener, exactly like a
        // widget's ref.watch would — it is plain @riverpod (autoDispose), so
        // without an active listener it could be torn down between reads and
        // the invalidation effect would be untestable.
        container.listen(totalStorageUsedProvider, (_, _) {});

        await container.read(downloadsProvider.future);
        await container.read(totalStorageUsedProvider.future);
        verify(() => repository.getDownloads()).called(1);
        verify(() => repository.getTotalStorageUsed()).called(1);

        when(() => repository.getDownloads())
            .thenAnswer((_) async => Right([_lesson('1'), _lesson('2')]));

        changeStreamController.add(null);
        await _settle();

        final state = container.read(downloadsProvider);
        expect(state.value, hasLength(2));
        // mocktail's called() counts invocations since the *last verify* of
        // this same call, not the cumulative total since mock creation —
        // so this is 1 new call (the stream-triggered refresh), not 2.
        verify(() => repository.getDownloads()).called(1);

        // The stream handler calls ref.invalidate(totalStorageUsedProvider);
        // since it's actively listened to, it recomputes and the next read
        // reflects that — this is what proves invalidation actually fired.
        final usage = await container.read(totalStorageUsedProvider.future);
        expect(usage, 1024);
        // Same reasoning: 1 new call since the previous verify.
        verify(() => repository.getTotalStorageUsed()).called(1);
      },
    );

    test(
      'a repository failure during a changeStream refresh sets AsyncError '
      'without crashing the listener',
      () async {
        when(() => repository.getDownloads())
            .thenAnswer((_) async => Right([_lesson('1')]));
        when(() => repository.getTotalStorageUsed())
            .thenAnswer((_) async => const Right(0));

        await container.read(downloadsProvider.future);

        const failure = StorageFailure('disk read error');
        when(() => repository.getDownloads())
            .thenAnswer((_) async => const Left(failure));

        changeStreamController.add(null);
        await _settle();

        final state = container.read(downloadsProvider);
        expect(state.hasError, isTrue);
        expect(state.error, same(failure));
      },
    );
  });

  group('DownloadsNotifier.startDownload', () {
    test('on success, refreshes the list from the repository', () async {
      when(() => repository.getDownloads())
          .thenAnswer((_) async => const Right([]));
      await container.read(downloadsProvider.future);

      when(
        () => repository.startDownload(
          lessonId: 'lesson-1',
          courseId: 'course-1',
          courseTitle: 'Course',
          title: 'Lesson',
          videoUrl: 'https://example.com/video.mp4',
          quality: VideoQuality.p720,
        ),
      ).thenAnswer((_) async => Right(_lesson('1')));
      when(() => repository.getDownloads())
          .thenAnswer((_) async => Right([_lesson('1')]));

      final notifier = container.read(downloadsProvider.notifier);
      await notifier.startDownload(
        lessonId: 'lesson-1',
        courseId: 'course-1',
        courseTitle: 'Course',
        title: 'Lesson',
        videoUrl: 'https://example.com/video.mp4',
        quality: VideoQuality.p720,
      );

      final state = container.read(downloadsProvider);
      expect(state.value, hasLength(1));
    });

    test(
      'on failure, sets AsyncError on the provider AND rethrows to the caller',
      () async {
        when(() => repository.getDownloads())
            .thenAnswer((_) async => const Right([]));
        await container.read(downloadsProvider.future);

        const failure = AlreadyDownloadedFailure();
        when(
          () => repository.startDownload(
            lessonId: 'lesson-1',
            courseId: 'course-1',
            courseTitle: 'Course',
            title: 'Lesson',
            videoUrl: 'https://example.com/video.mp4',
            quality: VideoQuality.p720,
          ),
        ).thenAnswer((_) async => const Left(failure));

        final notifier = container.read(downloadsProvider.notifier);

        await expectLater(
          notifier.startDownload(
            lessonId: 'lesson-1',
            courseId: 'course-1',
            courseTitle: 'Course',
            title: 'Lesson',
            videoUrl: 'https://example.com/video.mp4',
            quality: VideoQuality.p720,
          ),
          throwsA(same(failure)),
        );

        final state = container.read(downloadsProvider);
        expect(state.hasError, isTrue);
        expect(state.error, same(failure));
      },
    );
  });

  // ── Fixed: pauseDownload/resumeDownload/cancelDownload/deleteDownload/
  // cleanupExpired now fold the use case's Either result exactly like
  // startDownload — on failure they set AsyncError AND rethrow to the
  // caller, instead of silently swallowing a Left(failure).
  group('DownloadsNotifier action methods — success path', () {
    test('pauseDownload calls the use case then refreshes', () async {
      when(() => repository.getDownloads()).thenAnswer(
        (_) async => Right([_lesson('1', status: DownloadStatus.downloading)]),
      );
      await container.read(downloadsProvider.future);

      when(() => repository.pauseDownload('download-1'))
          .thenAnswer((_) async => const Right(null));
      when(() => repository.getDownloads()).thenAnswer(
        (_) async => Right([_lesson('1', status: DownloadStatus.paused)]),
      );

      final notifier = container.read(downloadsProvider.notifier);
      await notifier.pauseDownload('download-1');

      verify(() => repository.pauseDownload('download-1')).called(1);
      expect(
        container.read(downloadsProvider).value?.first.status,
        DownloadStatus.paused,
      );
    });

    test('resumeDownload calls the use case then refreshes', () async {
      when(() => repository.getDownloads())
          .thenAnswer((_) async => const Right([]));
      await container.read(downloadsProvider.future);

      when(() => repository.resumeDownload('download-1'))
          .thenAnswer((_) async => const Right(null));
      when(() => repository.getDownloads())
          .thenAnswer((_) async => Right([_lesson('1')]));

      final notifier = container.read(downloadsProvider.notifier);
      await notifier.resumeDownload('download-1');

      verify(() => repository.resumeDownload('download-1')).called(1);
      expect(container.read(downloadsProvider).value, hasLength(1));
    });

    test('cancelDownload calls the use case then refreshes', () async {
      when(() => repository.getDownloads())
          .thenAnswer((_) async => Right([_lesson('1')]));
      await container.read(downloadsProvider.future);

      when(() => repository.cancelDownload('download-1'))
          .thenAnswer((_) async => const Right(null));
      when(() => repository.getDownloads())
          .thenAnswer((_) async => const Right([]));

      final notifier = container.read(downloadsProvider.notifier);
      await notifier.cancelDownload('download-1');

      verify(() => repository.cancelDownload('download-1')).called(1);
      expect(container.read(downloadsProvider).value, isEmpty);
    });

    test('deleteDownload calls the use case then refreshes', () async {
      when(() => repository.getDownloads())
          .thenAnswer((_) async => Right([_lesson('1')]));
      await container.read(downloadsProvider.future);

      when(() => repository.deleteDownload('download-1'))
          .thenAnswer((_) async => const Right(null));
      when(() => repository.getDownloads())
          .thenAnswer((_) async => const Right([]));

      final notifier = container.read(downloadsProvider.notifier);
      await notifier.deleteDownload('download-1');

      verify(() => repository.deleteDownload('download-1')).called(1);
      expect(container.read(downloadsProvider).value, isEmpty);
    });

    test('cleanupExpired calls the use case then refreshes', () async {
      when(() => repository.getDownloads())
          .thenAnswer((_) async => Right([_lesson('1'), _lesson('2')]));
      await container.read(downloadsProvider.future);

      when(() => repository.cleanupExpiredDownloads())
          .thenAnswer((_) async => const Right(1));
      when(() => repository.getDownloads())
          .thenAnswer((_) async => Right([_lesson('2')]));

      final notifier = container.read(downloadsProvider.notifier);
      await notifier.cleanupExpired();

      verify(() => repository.cleanupExpiredDownloads()).called(1);
      expect(container.read(downloadsProvider).value, hasLength(1));
    });
  });

  group('DownloadsNotifier action methods — failure path', () {
    test(
      'pauseDownload sets AsyncError AND rethrows on repository failure',
      () async {
        when(() => repository.getDownloads()).thenAnswer(
          (_) async => Right([_lesson('1', status: DownloadStatus.downloading)]),
        );
        await container.read(downloadsProvider.future);

        const failure = ServerFailure('pause failed');
        when(() => repository.pauseDownload('download-1'))
            .thenAnswer((_) async => const Left(failure));

        final notifier = container.read(downloadsProvider.notifier);

        await expectLater(
          notifier.pauseDownload('download-1'),
          throwsA(same(failure)),
        );

        final state = container.read(downloadsProvider);
        expect(state.hasError, isTrue);
        expect(state.error, same(failure));
      },
    );

    test(
      'resumeDownload sets AsyncError AND rethrows on repository failure',
      () async {
        when(() => repository.getDownloads())
            .thenAnswer((_) async => Right([_lesson('1')]));
        await container.read(downloadsProvider.future);

        const failure = ServerFailure('resume failed');
        when(() => repository.resumeDownload('download-1'))
            .thenAnswer((_) async => const Left(failure));

        final notifier = container.read(downloadsProvider.notifier);

        await expectLater(
          notifier.resumeDownload('download-1'),
          throwsA(same(failure)),
        );

        final state = container.read(downloadsProvider);
        expect(state.hasError, isTrue);
        expect(state.error, same(failure));
      },
    );

    test(
      'cancelDownload sets AsyncError AND rethrows on repository failure',
      () async {
        when(() => repository.getDownloads())
            .thenAnswer((_) async => Right([_lesson('1')]));
        await container.read(downloadsProvider.future);

        const failure = ServerFailure('cancel failed');
        when(() => repository.cancelDownload('download-1'))
            .thenAnswer((_) async => const Left(failure));

        final notifier = container.read(downloadsProvider.notifier);

        await expectLater(
          notifier.cancelDownload('download-1'),
          throwsA(same(failure)),
        );

        final state = container.read(downloadsProvider);
        expect(state.hasError, isTrue);
        expect(state.error, same(failure));
      },
    );

    test(
      'deleteDownload sets AsyncError AND rethrows on repository failure',
      () async {
        when(() => repository.getDownloads())
            .thenAnswer((_) async => Right([_lesson('1')]));
        await container.read(downloadsProvider.future);

        const failure = StorageFailure('delete failed');
        when(() => repository.deleteDownload('download-1'))
            .thenAnswer((_) async => const Left(failure));

        final notifier = container.read(downloadsProvider.notifier);

        await expectLater(
          notifier.deleteDownload('download-1'),
          throwsA(same(failure)),
        );

        final state = container.read(downloadsProvider);
        expect(state.hasError, isTrue);
        expect(state.error, same(failure));
      },
    );

    test(
      'cleanupExpired sets AsyncError AND rethrows on repository failure',
      () async {
        when(() => repository.getDownloads())
            .thenAnswer((_) async => Right([_lesson('1')]));
        await container.read(downloadsProvider.future);

        const failure = CacheFailure('cleanup failed');
        when(() => repository.cleanupExpiredDownloads())
            .thenAnswer((_) async => const Left(failure));

        final notifier = container.read(downloadsProvider.notifier);

        await expectLater(
          notifier.cleanupExpired(),
          throwsA(same(failure)),
        );

        final state = container.read(downloadsProvider);
        expect(state.hasError, isTrue);
        expect(state.error, same(failure));
      },
    );
  });

  group('DownloadsNotifier.refresh', () {
    test('a failure during refresh() sets AsyncError without throwing', () async {
      when(() => repository.getDownloads())
          .thenAnswer((_) async => const Right([]));
      await container.read(downloadsProvider.future);

      const failure = CacheFailure('reload failed');
      when(() => repository.getDownloads())
          .thenAnswer((_) async => const Left(failure));

      final notifier = container.read(downloadsProvider.notifier);
      // refresh() uses AsyncValue.guard — must not throw synchronously.
      await notifier.refresh();

      final state = container.read(downloadsProvider);
      expect(state.hasError, isTrue);
      expect(state.error, same(failure));
    });
  });

  group('Satellite providers', () {
    test('totalStorageUsedProvider folds a failure to 0', () async {
      when(() => repository.getTotalStorageUsed())
          .thenAnswer((_) async => const Left(CacheFailure('boom')));

      final result = await container.read(totalStorageUsedProvider.future);

      expect(result, 0);
    });

    test('totalStorageUsedProvider returns the real total on success', () async {
      when(() => repository.getTotalStorageUsed())
          .thenAnswer((_) async => const Right(2048));

      final result = await container.read(totalStorageUsedProvider.future);

      expect(result, 2048);
    });

    test('downloadByLessonId folds a failure to null', () async {
      when(() => repository.getDownloadByLessonId('lesson-1'))
          .thenAnswer((_) async => const Left(NotFoundFailure('missing')));

      final result = await container.read(
        downloadByLessonIdProvider('lesson-1').future,
      );

      expect(result, isNull);
    });

    test('downloadByLessonId returns the download on success', () async {
      when(() => repository.getDownloadByLessonId('lesson-1'))
          .thenAnswer((_) async => Right(_lesson('1')));

      final result = await container.read(
        downloadByLessonIdProvider('lesson-1').future,
      );

      expect(result?.id, '1');
    });

    test('downloadById folds a failure to null', () async {
      when(() => repository.getDownloadById('download-1'))
          .thenAnswer((_) async => const Left(NotFoundFailure('missing')));

      final result = await container.read(
        downloadByIdProvider('download-1').future,
      );

      expect(result, isNull);
    });

    test('downloadProgress streams progress updates from the repository', () async {
      final progressController = StreamController<DownloadProgress>();
      addTearDown(progressController.close);
      when(() => repository.watchProgress('download-1'))
          .thenAnswer((_) => progressController.stream);

      final events = <DownloadProgress>[];
      final sub = container.listen(
        downloadProgressProvider('download-1'),
        (_, next) {
          if (next.hasValue) events.add(next.value!);
        },
      );
      addTearDown(sub.close);

      progressController.add(
        const DownloadProgress(
          downloadId: 'download-1',
          lessonId: 'lesson-1',
          receivedBytes: 50,
          totalBytes: 100,
          progress: 0.5,
          status: DownloadStatus.downloading,
        ),
      );
      await _settle();

      expect(events, hasLength(1));
      expect(events.first.progress, 0.5);
    });
  });
}