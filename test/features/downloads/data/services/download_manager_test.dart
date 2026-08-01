import 'dart:async';
import 'dart:io';

import 'package:app/features/downloads/data/services/download_manager.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class MockDio extends Mock implements Dio {}

class MockFileDownloader extends Mock implements FileDownloader {}

/// Awaits several microtask turns. Used instead of a single
/// `Future.delayed(Duration.zero)` to reliably let `startDownload()`'s
/// internal `getApplicationDocumentsDirectory()`/`getTemporaryDirectory()`
/// calls (path_provider platform-channel round trips, silently caught on
/// failure) settle before asserting on state that's set right after them.
Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  // Needed for loadPinnedCertificatesAsset() (rootBundle.load) in the
  // certificate-pinning group below.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(CancelToken());
    registerFallbackValue(IOHttpClientAdapter());
    registerFallbackValue(DownloadTask(url: 'https://example.com', filename: 'f'));
  });

  late MockDio dio;
  late MockFileDownloader fileDownloader;
  late Directory tempDir;

  /// Builds a DownloadManager wired to the mocked Dio/FileDownloader, with
  /// notification configuration skipped (configureOnInit: false) since that
  /// touches background_downloader APIs unrelated to what these tests cover.
  DownloadManager buildManager({bool isAndroid = true}) {
    return DownloadManager(
      downloader: fileDownloader,
      dioFactory: () => dio,
      isAndroid: isAndroid,
      configureOnInit: false,
    );
  }

  /// Stubs the range-probe GET request to fail, forcing
  /// `_tryDownloadWithParallelRanges` to fall back to a plain
  /// `dio.download()` call — the simplest, most deterministic path through
  /// `_downloadWithDio` for tests that aren't specifically about parallel
  /// ranged downloads.
  void stubProbeUnsupported() {
    when(
      () => dio.get<ResponseBody>(
        any(),
        options: any(named: 'options'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenThrow(Exception('range probing not supported by this stub'));
  }

  setUp(() async {
    dio = MockDio();
    fileDownloader = MockFileDownloader();
    when(() => fileDownloader.taskForId(any())).thenAnswer((_) async => null);
    when(() => fileDownloader.cancelTaskWithId(any()))
        .thenAnswer((_) async => true);
    when(() => fileDownloader.cancelAll()).thenAnswer((_) async => true);

    tempDir = await Directory.systemTemp.createTemp('download_manager_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('startDownload — Android/Dio direct-download path', () {
    test(
      'downloads via a plain dio.download() when range probing fails, '
      'and reports progress',
      () async {
        stubProbeUnsupported();

        final progressUpdates = <List<int>>[];
        when(
          () => dio.download(
            any(),
            any(),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
          ),
        ).thenAnswer((invocation) async {
          final onReceiveProgress = invocation
              .namedArguments[#onReceiveProgress] as void Function(int, int);
          onReceiveProgress(50, 100);
          onReceiveProgress(100, 100);
          return Response<void>(
            requestOptions: RequestOptions(
              path: invocation.positionalArguments[0] as String,
            ),
          );
        });

        final manager = buildManager();
        final savePath = '${tempDir.path}/video.mp4';

        final id = await manager.startDownload(
          downloadId: 'dl-1',
          url: 'https://cdn.example.com/video.mp4',
          savePath: savePath,
          onProgress: (received, total) =>
              progressUpdates.add([received, total]),
        );

        expect(id, 'dl-1');
        expect(progressUpdates, [
          [50, 100],
          [100, 100],
        ]);
        expect(manager.isDownloadActive('dl-1'), isFalse);

        verify(
          () => dio.download(
            'https://cdn.example.com/video.mp4',
            savePath,
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
          ),
        ).called(1);
      },
    );

    test(
      'isDownloadActive/activeDownloadsCount reflect an in-flight download '
      'and clear on completion',
      () async {
        stubProbeUnsupported();
        final completer = Completer<Response<void>>();
        when(
          () => dio.download(
            any(),
            any(),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
          ),
        ).thenAnswer((_) => completer.future);

        final manager = buildManager();
        final savePath = '${tempDir.path}/video.mp4';

        final future = manager.startDownload(
          downloadId: 'dl-2',
          url: 'https://cdn.example.com/video.mp4',
          savePath: savePath,
          onProgress: (_, _) {},
        );
        // Let startDownload run up to the point it's awaiting dio.download().
        await _settle();

        expect(manager.isDownloadActive('dl-2'), isTrue);
        expect(manager.activeDownloadsCount, 1);

        completer.complete(
          Response<void>(requestOptions: RequestOptions(path: savePath)),
        );
        await future;

        expect(manager.isDownloadActive('dl-2'), isFalse);
        expect(manager.activeDownloadsCount, 0);
      },
    );

    test(
      'throws once the maximum concurrent downloads limit is reached',
      () async {
        stubProbeUnsupported();
        final completers = <Completer<Response<void>>>[];
        when(
          () => dio.download(
            any(),
            any(),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
          ),
        ).thenAnswer((_) {
          final c = Completer<Response<void>>();
          completers.add(c);
          return c.future;
        });

        final manager = buildManager();
        final futures = <Future<String>>[];
        for (var i = 0; i < 3; i++) {
          futures.add(
            manager.startDownload(
              downloadId: 'dl-max-$i',
              url: 'https://cdn.example.com/video-$i.mp4',
              savePath: '${tempDir.path}/video-$i.mp4',
              onProgress: (_, _) {},
            ),
          );
        }
        await _settle();
        expect(manager.activeDownloadsCount, 3);

        await expectLater(
          manager.startDownload(
            downloadId: 'dl-overflow',
            url: 'https://cdn.example.com/overflow.mp4',
            savePath: '${tempDir.path}/overflow.mp4',
            onProgress: (_, _) {},
          ),
          throwsA(isA<Exception>()),
        );

        // Resolve the 3 in-flight stubs so nothing leaks past the test.
        for (final c in completers) {
          c.complete(
            Response<void>(
              requestOptions: RequestOptions(path: tempDir.path),
            ),
          );
        }
        await Future.wait(futures);
      },
    );
  });

  group('startDownload — certificate pinning wiring', () {
    void stubSimpleDioDownload() {
      when(
        () => dio.download(
          any(),
          any(),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).thenAnswer(
        (invocation) async => Response<void>(
          requestOptions: RequestOptions(
            path: invocation.positionalArguments[0] as String,
          ),
        ),
      );
    }

    test('applies certificate pinning for a *.supabase.co URL', () async {
      stubProbeUnsupported();
      stubSimpleDioDownload();

      final manager = buildManager();
      await manager.startDownload(
        downloadId: 'dl-pin',
        url: 'https://myproject.supabase.co/storage/v1/video.mp4',
        savePath: '${tempDir.path}/video.mp4',
        onProgress: (_, _) {},
      );

      verify(() => dio.httpClientAdapter = any()).called(1);
    });

    test(
      'does NOT apply certificate pinning for an external CDN URL',
      () async {
        stubProbeUnsupported();
        stubSimpleDioDownload();

        final manager = buildManager();
        await manager.startDownload(
          downloadId: 'dl-nopin',
          url: 'https://cdn.example.com/video.mp4',
          savePath: '${tempDir.path}/video.mp4',
          onProgress: (_, _) {},
        );

        verifyNever(() => dio.httpClientAdapter = any());
      },
    );
  });

  group('pause/cancel delegation to the underlying FileDownloader', () {
    test('pauseDownload looks up the task via taskForId', () async {
      final manager = buildManager();
      await manager.pauseDownload('some-id');
      verify(() => fileDownloader.taskForId('some-id')).called(1);
    });

    test('cancelDownload delegates to cancelTaskWithId', () async {
      final manager = buildManager();
      await manager.cancelDownload('some-id');
      verify(() => fileDownloader.cancelTaskWithId('some-id')).called(1);
    });

    test('cancelAllDownloads delegates to cancelAll', () async {
      final manager = buildManager();
      await manager.cancelAllDownloads();
      verify(() => fileDownloader.cancelAll()).called(1);
    });
  });

  group('startDownload — non-Android FileDownloader path', () {
    // A minimal, valid fixture task to attach to fake stream updates.
    // Per background_downloader's own docs, `url` and `filename` are the
    // only required fields; metaData defaults to '' which makes
    // handleTokenRefresh() a safe, network-free no-op (it early-returns
    // whenever task.metaData.isEmpty).
    DownloadTask fixtureTask(String taskId) => DownloadTask(
      taskId: taskId,
      url: 'https://cdn.example.com/video.mp4',
      filename: 'video.mp4',
    );

    test('maps TaskProgressUpdate to onProgress(received, total)', () async {
      final updatesController = StreamController<TaskUpdate>();
      addTearDown(updatesController.close);
      when(
        () => fileDownloader.updates,
      ).thenAnswer((_) => updatesController.stream);
      when(() => fileDownloader.enqueue(any())).thenAnswer((_) async => true);

      final manager = buildManager(isAndroid: false);
      final progressUpdates = <List<int>>[];

      final future = manager.startDownload(
        downloadId: 'dl-progress',
        url: 'https://cdn.example.com/video.mp4',
        savePath: '${tempDir.path}/video.mp4',
        onProgress: (received, total) =>
            progressUpdates.add([received, total]),
      );
      await _settle();

      final task = fixtureTask('dl-progress');
      updatesController.add(TaskProgressUpdate(task, 0.5, 1000));
      await _settle();
      expect(progressUpdates, [
        [500, 1000],
      ]);

      // Complete the task so `future` doesn't leak past this test.
      updatesController.add(TaskStatusUpdate(task, TaskStatus.complete));
      await future;
    });

    test('resolves with the downloadId when TaskStatus.complete arrives', () async {
      final updatesController = StreamController<TaskUpdate>();
      addTearDown(updatesController.close);
      when(
        () => fileDownloader.updates,
      ).thenAnswer((_) => updatesController.stream);
      when(() => fileDownloader.enqueue(any())).thenAnswer((_) async => true);

      final manager = buildManager(isAndroid: false);
      final future = manager.startDownload(
        downloadId: 'dl-complete',
        url: 'https://cdn.example.com/video.mp4',
        savePath: '${tempDir.path}/video.mp4',
        onProgress: (_, _) {},
      );
      await _settle();

      updatesController.add(
        TaskStatusUpdate(fixtureTask('dl-complete'), TaskStatus.complete),
      );

      final id = await future;
      expect(id, 'dl-complete');
      expect(manager.isDownloadActive('dl-complete'), isFalse);
    });

    test(
      'rejects with an error when TaskStatus.canceled arrives',
      () async {
        final updatesController = StreamController<TaskUpdate>();
        addTearDown(updatesController.close);
        when(
          () => fileDownloader.updates,
        ).thenAnswer((_) => updatesController.stream);
        when(
          () => fileDownloader.enqueue(any()),
        ).thenAnswer((_) async => true);

        final manager = buildManager(isAndroid: false);
        final future = manager.startDownload(
          downloadId: 'dl-canceled',
          url: 'https://cdn.example.com/video.mp4',
          savePath: '${tempDir.path}/video.mp4',
          onProgress: (_, _) {},
        );
        await _settle();

        updatesController.add(
          TaskStatusUpdate(fixtureTask('dl-canceled'), TaskStatus.canceled),
        );

        await expectLater(future, throwsA(isA<Exception>()));
        expect(manager.isDownloadActive('dl-canceled'), isFalse);
      },
    );

    test(
      'falls back to a plain Dio download when TaskStatus.failed arrives',
      () async {
        final updatesController = StreamController<TaskUpdate>();
        addTearDown(updatesController.close);
        when(
          () => fileDownloader.updates,
        ).thenAnswer((_) => updatesController.stream);
        when(
          () => fileDownloader.enqueue(any()),
        ).thenAnswer((_) async => true);
        stubProbeUnsupported();
        when(
          () => dio.download(
            any(),
            any(),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
          ),
        ).thenAnswer(
          (invocation) async => Response<void>(
            requestOptions: RequestOptions(
              path: invocation.positionalArguments[0] as String,
            ),
          ),
        );

        final manager = buildManager(isAndroid: false);
        final savePath = '${tempDir.path}/video.mp4';
        final future = manager.startDownload(
          downloadId: 'dl-failed',
          url: 'https://cdn.example.com/video.mp4',
          savePath: savePath,
          onProgress: (_, _) {},
        );
        await _settle();

        updatesController.add(
          TaskStatusUpdate(fixtureTask('dl-failed'), TaskStatus.failed),
        );

        final id = await future;
        expect(id, 'dl-failed');
        verify(
          () => dio.download(
            'https://cdn.example.com/video.mp4',
            savePath,
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
          ),
        ).called(1);
      },
    );

    test('throws immediately when enqueue() returns false', () async {
      final updatesController = StreamController<TaskUpdate>();
      addTearDown(updatesController.close);
      when(
        () => fileDownloader.updates,
      ).thenAnswer((_) => updatesController.stream);
      when(
        () => fileDownloader.enqueue(any()),
      ).thenAnswer((_) async => false);

      final manager = buildManager(isAndroid: false);

      await expectLater(
        manager.startDownload(
          downloadId: 'dl-enqueue-fail',
          url: 'https://cdn.example.com/video.mp4',
          savePath: '${tempDir.path}/video.mp4',
          onProgress: (_, _) {},
        ),
        throwsA(isA<Exception>()),
      );
      expect(manager.isDownloadActive('dl-enqueue-fail'), isFalse);
    });
  });
}