import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:dio/dio.dart'
    show
        CancelToken,
        Dio,
        DioException,
        DioExceptionType,
        Options,
        ProgressCallback,
        ResponseBody,
        ResponseType;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/certificate_pinning.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/services/encryption_service.dart'
    show
        PlannedChunk,
        chunkIndexFromPlan,
        chunkedFormatHeaderBytes,
        encryptChunkBatch,
        planChunkLayout,
        totalEncryptedSizeForPlan;
import '../../../../shared/utils/global_error_handler.dart';
import '../../data/datasources/download_remote_ds.dart';
import '../../domain/entities/download_enums.dart';
import 'chunk_scheduler.dart';
import 'chunk_transport.dart';

/// Top-level callback triggered by background_downloader when a task's
/// server link is nearing expiration (TTL < 6h).
///
/// Refreshes the short-lived server URL via Supabase Edge Function
/// before any HTTP request attempt (start, retry, resume).
@pragma('vm:entry-point')
Future<Task?> handleTokenRefresh(Task task) async {
  try {
    if (task is! DownloadTask || task.metaData.isEmpty) return null;
    final data = jsonDecode(task.metaData) as Map<String, dynamic>;
    final sourceUrl = data['sourceUrl'] as String?;
    final qualityLabel = data['qualityLabel'] as String?;
    final trackType = data['trackType'] as String? ?? 'video';

    if (sourceUrl == null || sourceUrl.isEmpty) return null;

    final freshUrl = await fetchFreshTrackUrl(
          sourceUrl: sourceUrl,
          qualityLabel: qualityLabel,
          trackType: trackType,
        ) ??
        task.url;

    if (kDebugMode) {
      debugPrint(
        '🔄 [handleTokenRefresh] Refreshed $trackType link for task ${task.taskId}',
      );
    }

    return task.copyWith(url: freshUrl);
  } catch (e, stack) {
    if (kDebugMode) {
      debugPrint('⚠️ [handleTokenRefresh] Link refresh failed: $e\n$stack');
    }
    // This callback can run in a background isolate (see
    // _supabaseClientForBackgroundCallback's re-init fallback above),
    // where Sentry may never have been initialized -- GlobalErrorHandler
    // .logError() already wraps Sentry.captureException() in its own
    // try/catch and no-ops safely in that case, so it's safe to call
    // unconditionally here. Without this, a failed background link
    // refresh (which silently degrades a download's retry behavior)
    // produced zero production observability signal at all.
    GlobalErrorHandler.logError(e, stack);
    return null;
  }
}

/// Re-resolves a fresh, non-expired CDN URL for [trackType] ('video' or
/// 'audio') from [sourceUrl] via the video-info Edge Function.
///
/// Used both by [handleTokenRefresh] (background_downloader's pre-attempt
/// hook, on platforms/paths that route through it) and by
/// [DownloadManager]'s Dio path when a download fails *partway through*
/// with an authorization error that looks like link expiry — a Range GET
/// against an already-expired signed URL fails identically no matter how
/// many times it's retried verbatim, so recovering from it needs a fresh
/// URL, not just a delay-and-retry (see [looksLikeExpiredLinkError] and
/// its use in `_downloadWithDio`).
///
/// Returns null (never throws) if no fresher URL could be resolved, so
/// callers can fall back to their existing URL/error handling.
@pragma('vm:entry-point')
Future<String?> fetchFreshTrackUrl({
  required String sourceUrl,
  required String? qualityLabel,
  required String trackType,
}) async {
  try {
    final client = await _supabaseClientForBackgroundCallback();
    final remoteDs = DownloadRemoteDataSource(client);
    final freshInfo = await remoteDs.getVideoInfo(sourceUrl);

    final quality = qualityLabel != null
        ? VideoQuality.fromLabel(qualityLabel)
        : VideoQuality.p720;

    final matchingFormats = freshInfo.formats
        .where((format) => format.quality == quality.label)
        .toList();
    final selectedFormat =
        matchingFormats.isNotEmpty ? matchingFormats.first : null;

    return trackType == 'audio'
        ? (selectedFormat?.audioUrl ?? freshInfo.audio?.url)
        : (selectedFormat?.videoUrl ??
            (freshInfo.formats.isNotEmpty
                ? freshInfo.formats.first.videoUrl
                : null));
  } catch (e, stack) {
    if (kDebugMode) {
      debugPrint('⚠️ [fetchFreshTrackUrl] Link refresh failed: $e\n$stack');
    }
    // See the matching comment in handleTokenRefresh() above: this is
    // called from the same possibly-uninitialized background isolate,
    // and GlobalErrorHandler.logError() is safe to call unconditionally
    // there.
    GlobalErrorHandler.logError(e, stack);
    return null;
  }
}

Future<SupabaseClient> _supabaseClientForBackgroundCallback() async {
  try {
    return Supabase.instance.client;
  } catch (_) {
    await SupabaseService.initialize();
    return Supabase.instance.client;
  }
}

/// Download manager backed by [FileDownloader] (background_downloader).
///
/// Supports background persistence across app kills/pauses, native iOS/Android
/// background workers, progress callbacks, and automatic server link refresh.
class DownloadManager {
  final FileDownloader _downloader;
  final Dio Function() _dioFactory;
  final bool _isAndroid;
  final Future<List<List<int>>> Function() _pinnedCertsLoader;
  final Map<String, StreamSubscription<TaskUpdate>> _subscriptions = {};
  final Map<String, CancelToken> _dioCancelTokens = {};
  final Set<String> _activeDownloadIds = {};
  static const int _maxConcurrentDownloads = 3;
  static const int _parallelDownloadMinBytes = 8 * 1024 * 1024;
  static const int _parallelDownloadLargeBytes = 80 * 1024 * 1024;

  // ── Range-worker resilience (P4 networking reliability) ──────────────────
  //
  // Every range/chunk-group GET below deliberately sets `receiveTimeout:
  // Duration.zero` (no timeout) because Dio's receiveTimeout would otherwise
  // bound the *entire* streamed transfer, not just idle gaps — a large video
  // legitimately taking minutes would be aborted by a short receiveTimeout,
  // and a receiveTimeout long enough to tolerate that defeats the point of
  // having one. That previously left stalled connections (dead socket, no
  // more bytes, no error either) to hang indefinitely — which is what a
  // "download is slow, then eventually fails" report usually is: not slow,
  // stalled, with no bound on how long it stalls before something upstream
  // (OS/CDN) finally kills the socket and the whole worker throws with zero
  // retry. `Stream.timeout` below re-introduces a bound, but as an *idle*
  // timeout (reset on every received chunk) instead of a whole-transfer one.
  //
  // Combined with genuinely zero retry on any transient error (one flaky
  // packet anywhere aborted the whole `Future.wait` of workers, and — for
  // the encrypted pipelined path — the *entire* download restarts from byte
  // 0 next time, per `startEncryptedDownload`'s doc comment), this made any
  // network hiccup during a large download disproportionately costly.
  static const Duration _streamIdleTimeout = Duration(seconds: 20);
  static const int _maxWorkerAttempts = 4;
  static const Duration _retryBaseDelay = Duration(seconds: 1);
  static const Duration _retryMaxDelay = Duration(seconds: 15);

  /// Whether [error] is safe to retry: a network-layer/idle-timeout failure
  /// (or a transient-looking server response), as opposed to a definitive
  /// failure (bad credentials/URL, deliberate cancellation) that retrying
  /// cannot fix. Range GETs are idempotent, so retrying them is always safe
  /// from a correctness standpoint — this only decides whether it's *useful*.
  @visibleForTesting
  static bool isTransientDownloadError(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
        case DioExceptionType.unknown:
          return true;
        case DioExceptionType.badResponse:
          final code = error.response?.statusCode;
          return code == 408 || code == 429 || (code != null && code >= 500);
        default:
          return false;
      }
    }
    // Stream.timeout() surfaces a stalled connection as TimeoutException;
    // "server closed the connection early" / empty stream body surface as
    // TimeoutException or StateError — both are worth retrying.
    return error is TimeoutException || error is StateError;
  }

  /// Whether [error] looks like a rejected/expired signed CDN URL (as
  /// opposed to a genuine transient network error). Retrying the same URL
  /// against this can't succeed — the fix is a fresh URL (see
  /// `fetchFreshTrackUrl`), not a delay.
  @visibleForTesting
  static bool looksLikeExpiredLinkError(Object error) {
    if (error is DioException && error.type == DioExceptionType.badResponse) {
      final code = error.response?.statusCode;
      return code == 401 || code == 403 || code == 410;
    }
    return false;
  }

  static Future<void> _delayBeforeRetry(int attempt) async {
    final scaled = _retryBaseDelay * (1 << (attempt - 1));
    await Future.delayed(scaled > _retryMaxDelay ? _retryMaxDelay : scaled);
  }

  /// [dioFactory], [isAndroid], [configureOnInit], and [pinnedCertsLoader]
  /// exist purely as testing seams — production code should never pass them.
  ///
  /// - [dioFactory]/[isAndroid]: without them, `flutter test` (host, not a
  ///   real Android device) can never exercise the Android-direct-Dio
  ///   download path, since `Platform.isAndroid` is always false on host.
  /// - [configureOnInit]: skips the one-time `_configureDownloader()` call
  ///   (notification channel + Android config), which talks to the real
  ///   `background_downloader` plugin API. Tests that don't care about
  ///   notification wiring can set this to `false` to avoid depending on
  ///   that API surface entirely.
  DownloadManager({
    FileDownloader? downloader,
    @visibleForTesting Dio Function()? dioFactory,
    @visibleForTesting bool? isAndroid,
    @visibleForTesting bool configureOnInit = true,
    @visibleForTesting Future<List<List<int>>> Function()? pinnedCertsLoader,
  })  : _downloader = downloader ?? FileDownloader(),
        _dioFactory = dioFactory ?? (() => Dio()),
        _isAndroid = isAndroid ?? Platform.isAndroid,
        _pinnedCertsLoader = pinnedCertsLoader ?? loadPinnedCertificatesAsset {
    if (configureOnInit) _configureDownloader();
  }

  /// Whether the fast parallel-range Dio path should be attempted for this
  /// platform/moment, instead of falling back to the plugin-driven
  /// `background_downloader` queue.
  ///
  /// Android: always eligible — downloads already run in a foreground
  /// service (`Config.runInForeground` in [_configureDownloader]), so a raw
  /// Dio connection surviving isn't a concern.
  ///
  /// iOS: a raw Dio HTTP connection is *not* a native `URLSession`
  /// background transfer the way `background_downloader`'s tasks are — if
  /// the app is backgrounded mid-download, iOS can suspend or drop the
  /// connection outright, silently failing a download that would otherwise
  /// have survived via the plugin's native background session. So on iOS
  /// the fast path is only taken while the app is confirmed to be in the
  /// foreground; otherwise every call site here falls back to the
  /// `background_downloader` queue path, same as before this change.
  /// `lifecycleState == null` (e.g. very early in app startup, before the
  /// first frame) is treated as foreground rather than blocking downloads
  /// that legitimately start there.
  bool get _dioParallelEligiblePlatform {
    if (_isAndroid) return true;
    final state = WidgetsBinding.instance.lifecycleState;
    return state == AppLifecycleState.resumed;
  }

  void _configureDownloader() {
    _downloader.configureNotification(
      running: const TaskNotification(
        'EduZone download', // check-ignore
        'Downloading {filename}: {progress}', // check-ignore
      ),
      complete: const TaskNotification(
        'EduZone download', // check-ignore
        'Download complete', // check-ignore
      ),
      error: const TaskNotification(
        'EduZone download', // check-ignore
        'Download failed', // check-ignore
      ),
      paused: const TaskNotification(
        'EduZone download', // check-ignore
        'Download paused', // check-ignore
      ),
      canceled: const TaskNotification(
        'EduZone download', // check-ignore
        'Download canceled', // check-ignore
      ),
      progressBar: true,
    );
    _downloader.configure(
      androidConfig: (Config.runInForeground, Config.always),
    );
  }

  /// Starts or enqueues a download task from [url] to [savePath].
  ///
  /// [onProgress] callback receives (receivedBytes, totalBytes).
  /// [sourceUrl] and [qualityLabel] enable automatic server link renewal
  /// if the download pauses and resumes after link expiration.
  Future<String> startDownload({
    String? downloadId,
    required String url,
    required String savePath,
    required ProgressCallback onProgress,
    Map<String, String>? headers,
    String? sourceUrl,
    String? qualityLabel,
    String trackType = 'video',
  }) async {
    if (_activeDownloadIds.length >= _maxConcurrentDownloads) {
      throw Exception('Maximum concurrent downloads limit reached'); // check-ignore
    }

    final effectiveDownloadId =
        downloadId ?? DateTime.now().millisecondsSinceEpoch.toString();

    _activeDownloadIds.add(effectiveDownloadId);

    BaseDirectory baseDirectory = BaseDirectory.applicationDocuments;
    String directory = 'downloads';
    final fileName = p.basename(savePath);

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      if (savePath.startsWith(appDocDir.path)) {
        baseDirectory = BaseDirectory.applicationDocuments;
        final relDir = p.dirname(savePath.substring(appDocDir.path.length));
        directory = relDir.startsWith('/') ? relDir.substring(1) : relDir;
      } else {
        final tempDir = await getTemporaryDirectory();
        if (savePath.startsWith(tempDir.path)) {
          baseDirectory = BaseDirectory.temporary;
          final relDir = p.dirname(savePath.substring(tempDir.path.length));
          directory = relDir.startsWith('/') ? relDir.substring(1) : relDir;
        }
      }
    } catch (_) {
      // Fall back to applicationDocuments + downloads
    }

    final metaDataMap = <String, dynamic>{
      if (sourceUrl != null && sourceUrl.isNotEmpty) 'sourceUrl': sourceUrl,
      if (qualityLabel != null && qualityLabel.isNotEmpty)
        'qualityLabel': qualityLabel,
      if (sourceUrl != null && sourceUrl.isNotEmpty) 'trackType': trackType,
    };

    final effectiveHeaders = <String, String>{
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/120.0.0.0 Mobile Safari/537.36',
      'Referer': 'https://www.youtube.com/',
      ...?headers,
    };

    final task = DownloadTask(
      taskId: effectiveDownloadId,
      url: url,
      headers: effectiveHeaders,
      baseDirectory: baseDirectory,
      directory: directory,
      filename: fileName,
      allowPause: true,
      updates: Updates.statusAndProgress,
      metaData: metaDataMap.isEmpty ? '' : jsonEncode(metaDataMap),
      options: sourceUrl == null || sourceUrl.isEmpty
          ? null
          : TaskOptions(onTaskStart: handleTokenRefresh),
    );

    if (_dioParallelEligiblePlatform) {
      final cancelToken = CancelToken();
      _dioCancelTokens[effectiveDownloadId] = cancelToken;
      try {
        await _downloadWithDio(
          task: task,
          originalUrl: url,
          savePath: savePath,
          headers: effectiveHeaders,
          cancelToken: cancelToken,
          onProgress: onProgress,
        );
        return effectiveDownloadId;
      } finally {
        _activeDownloadIds.remove(effectiveDownloadId);
        _dioCancelTokens.remove(effectiveDownloadId);
      }
    }

    final completer = Completer<String>();

    // ignore: cancel_subscriptions
    final sub = _downloader.updates.listen((update) {
      if (update.task.taskId != effectiveDownloadId) return;

      if (update is TaskProgressUpdate) {
        final total =
            update.hasExpectedFileSize ? update.expectedFileSize : 100;
        final received = (update.progress * total).round();
        onProgress(received, total);
      } else if (update is TaskStatusUpdate) {
        switch (update.status) {
          case TaskStatus.complete:
            _activeDownloadIds.remove(effectiveDownloadId);
            _cleanSubscription(effectiveDownloadId);
            if (!completer.isCompleted) {
              unawaited(_ensureFileAtSavePath(update.task, savePath).then((_) {
                if (!completer.isCompleted) {
                  completer.complete(effectiveDownloadId);
                }
              }).catchError((Object e) {
                if (!completer.isCompleted) {
                  completer.complete(effectiveDownloadId);
                }
              }));
            }
            break;
          case TaskStatus.canceled:
            _activeDownloadIds.remove(effectiveDownloadId);
            _cleanSubscription(effectiveDownloadId);
            if (!completer.isCompleted) {
              completer.completeError(
                Exception('Download canceled with status: ${update.status}'), // check-ignore
              );
            }
            break;
          case TaskStatus.failed:
          case TaskStatus.notFound:
            _activeDownloadIds.remove(effectiveDownloadId);
            _cleanSubscription(effectiveDownloadId);
            if (!completer.isCompleted) {
              final failureDetails = _formatFailureDetails(update);
              if (kDebugMode) {
                debugPrint(
                  'Download task $effectiveDownloadId failed: $failureDetails',
                );
              }
              unawaited(
                _downloadWithDio(
                  task: update.task,
                  originalUrl: url,
                  savePath: savePath,
                  headers: effectiveHeaders,
                  cancelToken: CancelToken(),
                  onProgress: onProgress,
                ).then((_) {
                  if (!completer.isCompleted) {
                    completer.complete(effectiveDownloadId);
                  }
                }).catchError((Object e) {
                  if (!completer.isCompleted) {
                    completer.completeError(
                      Exception('$failureDetails | Dio retry failed: $e'), // check-ignore
                    );
                  }
                }),
              );
            }
            break;
          case TaskStatus.paused:
            _activeDownloadIds.remove(effectiveDownloadId);
            break;
          default:
            break;
        }
      }
    });

    _subscriptions[effectiveDownloadId] = sub;

    final enqueued = await _downloader.enqueue(task);
    if (!enqueued) {
      _activeDownloadIds.remove(effectiveDownloadId);
      _cleanSubscription(effectiveDownloadId);
      throw Exception('Failed to enqueue download task: $effectiveDownloadId'); // check-ignore
    }

    return completer.future;
  }

  /// Downloads [url] and writes it directly as an AES-256-GCM chunked
  /// encrypted file at [encryptedSavePath] — plaintext never touches disk.
  ///
  /// Supersedes the old two-step flow used by callers today (download
  /// plaintext to a `.tmp` file via [startDownload], then run
  /// [EncryptionService.encryptFile] as a separate sequential pass over the
  /// whole file afterward): those two steps were each other's biggest
  /// source of "wait more after the download already finished" — this
  /// makes them the same pass. Each parallel range worker encrypts the
  /// bytes it receives as they arrive and writes them straight to their
  /// final position in [encryptedSavePath]. Concurrent, out-of-order writes
  /// to the same destination file are safe here because every chunk's
  /// on-disk offset is deterministic from its index alone — see
  /// [PlannedChunk] for why — so workers never need to coordinate beyond
  /// "who owns which chunk indices".
  ///
  /// Returns `null` if the pipelined path isn't usable for this download.
  /// The encrypted execution service treats this as a hard failure; it must
  /// not fall back to a plaintext temporary file. Reasons this returns
  /// `null`:
  /// - The server doesn't support Range requests, or the file is smaller
  ///   than [_parallelDownloadMinBytes] (not worth parallelizing).
  /// - [_dioParallelEligiblePlatform] is false (iOS, app backgrounded).
  /// - Any error during setup/download/encryption (network failure mid-way,
  ///   disk full, etc.).
  ///
  /// Byte-range resume: when [completedChunkIndexes] is non-empty and
  /// [encryptedSavePath] already exists, this resumes into the existing
  /// file instead of truncating it — only the chunks *not* in
  /// [completedChunkIndexes] are re-fetched (see `pendingPlan` below). A
  /// caller with no manifest/chunk-tracking available (i.e. that never
  /// passes [completedChunkIndexes]) still gets the old restart-from-zero
  /// behavior, since there's nothing durable to resume from in that case.
  Future<String?> startEncryptedDownload({
    required String url,
    required String encryptedSavePath,
    required String encryptionKeyBase64,
    required ProgressCallback onProgress,
    String? downloadId,
    Map<String, String>? headers,
    Future<void> Function(int totalBytes, List<PlannedChunk> plan)?
        onPlanCreated,
    Future<void> Function(PlannedChunk chunk)? onChunkCommitted,
    Set<int>? completedChunkIndexes,
    String? sourceUrl,
    String? qualityLabel,
    String trackType = 'video',
  }) async {
    if (!_dioParallelEligiblePlatform) return null;
    if (_activeDownloadIds.length >= _maxConcurrentDownloads) {
      throw Exception('Maximum concurrent downloads limit reached'); // check-ignore
    }

    final effectiveDownloadId =
        downloadId ?? DateTime.now().millisecondsSinceEpoch.toString();

    final effectiveHeaders = <String, String>{
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/120.0.0.0 Mobile Safari/537.36',
      'Referer': 'https://www.youtube.com/',
      ...?headers,
    };

    final dio = _dioFactory();
    if (isSupabaseHost(url, configuredSupabaseUrl: AppConstants.supabaseUrl)) {
      final certs = await loadPinnedCertificatesAsset();
      if (certs.isNotEmpty) {
        applyCertificatePinning(dio, pinnedCertificatesPem: certs);
      }
    }

    final cancelToken = CancelToken();
    _dioCancelTokens[effectiveDownloadId] = cancelToken;
    _activeDownloadIds.add(effectiveDownloadId);

    RandomAccessFile? raf;
    try {
      final probe = await _probeRangeDownload(
        dio: dio,
        url: url,
        headers: effectiveHeaders,
        cancelToken: cancelToken,
      );
      if (probe == null || probe.totalBytes < _parallelDownloadMinBytes) {
        return null;
      }

      final plan = planChunkLayout(probe.totalBytes);
      await onPlanCreated?.call(probe.totalBytes, plan);
      final completed = completedChunkIndexes ?? const <int>{};
      final pendingPlan = plan
          .where((chunk) => !completed.contains(chunk.index))
          .toList(growable: false);
      final destFile = File(encryptedSavePath);
      await destFile.parent.create(recursive: true);
      final hasResumableFile = completed.isNotEmpty && await destFile.exists();
      if (!hasResumableFile && await destFile.exists()) {
        await destFile.delete();
      }

      // Single open here — deliberately NOT one `File.open()` per worker
      // the way the plaintext `_downloadRange` path does. `FileMode.write`
      // truncates on *every* open, so if each worker opened its own handle
      // on this same path, whichever worker's open() call happened to land
      // last would silently wipe out bytes already written by the others.
      // Opening exactly once here (before any worker starts) and sharing
      // this single handle — serialized through [_AsyncFileWriteLock] below
      // — sidesteps that risk entirely rather than depending on the exact
      // truncate/seek semantics of any particular `FileMode`.
      if (!await destFile.exists()) await destFile.create(recursive: true);
      raf = await destFile.open(mode: FileMode.writeOnly);
      if (!hasResumableFile) await raf.writeFrom(chunkedFormatHeaderBytes);
      await raf.truncate(totalEncryptedSizeForPlan(plan));

      final chunkCount = probe.totalBytes >= _parallelDownloadLargeBytes ? 6 : 4;
      final workerChunkGroups = _splitChunksAcrossWorkers(pendingPlan, chunkCount);
      final progressByWorker = List<int>.filled(workerChunkGroups.length, 0);
      final writeLock = _AsyncFileWriteLock();
      final chunkTransport = DioChunkTransport(dio);

      if (kDebugMode) {
        debugPrint(
          'Encrypted parallel download: ${workerChunkGroups.length} workers, '
          '${plan.length} chunks, ${probe.totalBytes} plaintext bytes',
        );
      }

      onProgress(
        completed
            .where((index) => index >= 0 && index < plan.length)
            .map((index) => plan[index].plaintextLength)
            .fold<int>(0, (sum, bytes) => sum + bytes),
        probe.totalBytes,
      );

      await ChunkScheduler(concurrency: workerChunkGroups.length).run<int>(
        items: [for (var i = 0; i < workerChunkGroups.length; i++) i],
        execute: (workerIndex) => _downloadAndEncryptChunkGroup(
          transport: chunkTransport,
          url: url,
          headers: effectiveHeaders,
          raf: raf!,
          writeLock: writeLock,
          chunks: workerChunkGroups[workerIndex],
          workerIndex: workerIndex,
          progressByWorker: progressByWorker,
          totalPlaintextBytes: probe.totalBytes,
          keyBase64: encryptionKeyBase64,
          cancelToken: cancelToken,
          onChunkCommitted: onChunkCommitted,
          onProgress: onProgress,
          sourceUrl: sourceUrl,
          qualityLabel: qualityLabel,
          trackType: trackType,
        ),
      );

      onProgress(probe.totalBytes, probe.totalBytes);

      // The index is fully deterministic from the plan — no need to
      // accumulate it chunk-by-chunk the way the single-isolate whole-file
      // encrypt path does; write it once, now that every chunk is on disk.
      final idx = chunkIndexFromPlan(plan, probe.totalBytes);
      final idxFile = File('$encryptedSavePath.idx');
      await idxFile.writeAsString(jsonEncode(idx.toJson()), flush: true);

      return effectiveDownloadId;
    } catch (e) {
      if (cancelToken.isCancelled) rethrow;
      if (kDebugMode) {
        debugPrint(
          'Encrypted parallel download failed, caller should fall back: $e',
        );
      }
      return null;
    } finally {
      await raf?.close();
      _activeDownloadIds.remove(effectiveDownloadId);
      _dioCancelTokens.remove(effectiveDownloadId);
    }
  }

  List<List<PlannedChunk>> _splitChunksAcrossWorkers(
    List<PlannedChunk> plan,
    int workerCount,
  ) {
    if (plan.isEmpty) return const [];
    final effectiveWorkers = workerCount < plan.length ? workerCount : plan.length;
    final perWorker = (plan.length / effectiveWorkers).ceil();
    final groups = <List<PlannedChunk>>[];
    for (var start = 0; start < plan.length; start += perWorker) {
      final end = start + perWorker < plan.length ? start + perWorker : plan.length;
      groups.add(plan.sublist(start, end));
    }
    return groups;
  }

  /// Downloads the byte range covering [chunks] (a contiguous, chunk-aligned
  /// slice of the overall plan — see [_splitChunksAcrossWorkers]), encrypts
  /// each chunk as soon as enough bytes for it have arrived, and writes the
  /// result straight to its precomputed position via [raf]/[writeLock].
  Future<void> _downloadAndEncryptChunkGroup({
    required ChunkTransport transport,
    required String url,
    required Map<String, String> headers,
    required RandomAccessFile raf,
    required _AsyncFileWriteLock writeLock,
    required List<PlannedChunk> chunks,
    required int workerIndex,
    required List<int> progressByWorker,
    required int totalPlaintextBytes,
    required String keyBase64,
    required CancelToken cancelToken,
    Future<void> Function(PlannedChunk chunk)? onChunkCommitted,
    required ProgressCallback onProgress,
    String? sourceUrl,
    String? qualityLabel,
    String trackType = 'video',
  }) async {
    if (chunks.isEmpty) return;
    final rangeEnd = chunks.last.plaintextEnd;

    // Resume point for retries: only chunks that have actually been
    // encrypted and written to disk (via flushBatch, below) count as done.
    // On a transient failure we re-request from the next un-flushed chunk's
    // boundary rather than restarting this worker's whole range — anything
    // still sitting in [pending]/[batchChunks] at the moment of failure was
    // never written, so discarding it and re-fetching is safe and cheap
    // (at most `batchChunkCount` chunks of re-download per retry).
    var flushedChunkCount = 0;
    var attempt = 0;
    // Mutable, unlike [url]: a link-refresh (below) swaps this for a fresh
    // signed CDN URL without affecting sibling workers, which independently
    // refresh their own copy if/when they also hit an expired link.
    var effectiveUrl = url;
    var linkRefreshUsed = false;

    while (flushedChunkCount < chunks.length) {
      attempt++;
      final rangeStart = chunks[flushedChunkCount].plaintextStart;

      try {
        final response = await transport.openRange(
          url: effectiveUrl,
          start: rangeStart,
          end: rangeEnd,
          headers: headers,
          cancelToken: cancelToken,
        );

        // FIFO of not-yet-consumed network packets, so a chunk boundary
        // that falls mid-packet doesn't require re-copying everything
        // received so far — only the (small) remainder of the packet that
        // straddles it.
        final pending = <Uint8List>[];
        var pendingLength = 0;
        var chunkCursor = flushedChunkCount;
        var batchChunks = <PlannedChunk>[];
        var batchPlaintexts = <Uint8List>[];
        // ~2 MB of plaintext per `Isolate.run` call at the default 512 KB
        // chunk size — batched so a worker handling hundreds of chunks
        // doesn't pay isolate-spawn overhead per chunk (every chunk here is
        // unique, unlike the read-side LRU cache in `EdzLocalProxy`, so
        // there's no cache to fall back on to absorb that cost).
        const batchChunkCount = 4;

        Uint8List takeExactly(int n) {
          final out = Uint8List(n);
          var written = 0;
          while (written < n) {
            final first = pending.first;
            final need = n - written;
            if (first.length <= need) {
              out.setRange(written, written + first.length, first);
              written += first.length;
              pending.removeAt(0);
            } else {
              out.setRange(written, n, first);
              pending[0] = first.sublist(need);
              written = n;
            }
          }
          pendingLength -= n;
          return out;
        }

        Future<void> flushBatch() async {
          if (batchChunks.isEmpty) return;
          final toEncrypt = batchChunks;
          final toEncryptPlaintexts = batchPlaintexts;
          batchChunks = [];
          batchPlaintexts = [];

          final encrypted =
              await encryptChunkBatch(toEncryptPlaintexts, keyBase64);
          await writeLock.run(() async {
            for (var i = 0; i < toEncrypt.length; i++) {
              final c = toEncrypt[i];
              final rec = encrypted[i];
              final lengthBytes = ByteData(4)
                ..setInt32(0, rec.cipherWithTag.length);
              await raf.setPosition(c.encryptedOffset);
              await raf.writeFrom(rec.iv);
              await raf.writeFrom(lengthBytes.buffer.asUint8List());
              await raf.writeFrom(rec.cipherWithTag);
            }
          });
          if (onChunkCommitted != null) {
            for (final chunk in toEncrypt) {
              await onChunkCommitted(chunk);
            }
          }
          flushedChunkCount += toEncrypt.length;
        }

        await for (final data in response.stream.timeout(_streamIdleTimeout)) {
          if (cancelToken.isCancelled) {
            throw cancelToken.cancelError ?? StateError('Download canceled');
          }
          pending.add(data);
          pendingLength += data.length;
          progressByWorker[workerIndex] += data.length;
          final received = progressByWorker.fold<int>(0, (s, v) => s + v);
          onProgress(received, totalPlaintextBytes);

          while (chunkCursor < chunks.length &&
              pendingLength >= chunks[chunkCursor].plaintextLength) {
            final c = chunks[chunkCursor];
            batchChunks.add(c);
            batchPlaintexts.add(takeExactly(c.plaintextLength));
            chunkCursor++;
            if (batchChunks.length >= batchChunkCount) {
              await flushBatch();
            }
          }
        }

        await flushBatch();

        if (chunkCursor < chunks.length) {
          throw StateError(
            'Range download for worker $workerIndex ended with '
            '${chunks.length - chunkCursor} chunk(s) unfilled '
            '(server closed the connection early)',
          );
        }
        return;
      } catch (e) {
        if (cancelToken.isCancelled) rethrow;

        // An expired signed URL fails identically no matter how many times
        // the *same* URL is retried — see `_downloadWithDio`'s identical
        // pattern, which this mirrors for the primary encrypted-chunk path.
        // This one only fires once per worker; if the CDN URL was going to
        // expire mid-download, catching it here (rather than only in the
        // now-unreachable plaintext fallback) is what makes the "URL
        // refresh without losing verified progress" acceptance criterion
        // hold for the actual production path.
        if (!linkRefreshUsed &&
            sourceUrl != null &&
            sourceUrl.isNotEmpty &&
            looksLikeExpiredLinkError(e)) {
          linkRefreshUsed = true;
          final fresh = await fetchFreshTrackUrl(
            sourceUrl: sourceUrl,
            qualityLabel: qualityLabel,
            trackType: trackType,
          );
          if (fresh != null && fresh.isNotEmpty && fresh != effectiveUrl) {
            if (kDebugMode) {
              debugPrint(
                '🔄 [DownloadManager] Link expired mid-download for '
                'encrypted worker $workerIndex — refreshed and retrying '
                'from chunk $flushedChunkCount (not counted against the '
                'retry budget)',
              );
            }
            effectiveUrl = fresh;
            attempt--; // link refresh isn't a "retry" of the same failure
            continue;
          }
        }

        if (attempt >= _maxWorkerAttempts || !isTransientDownloadError(e)) {
          rethrow;
        }
        // Bytes received in the failed attempt beyond the last flush were
        // never encrypted/written, so roll the progress counter back to
        // what's actually durable — otherwise the retry's re-fetched bytes
        // would be double-counted in the combined progress total.
        final flushedPlaintextBytes = flushedChunkCount == 0
            ? 0
            : chunks[flushedChunkCount - 1].plaintextEnd -
                chunks.first.plaintextStart +
                1;
        progressByWorker[workerIndex] = flushedPlaintextBytes;
        if (kDebugMode) {
          debugPrint(
            'Encrypted chunk worker $workerIndex stalled/failed '
            '(attempt $attempt): $e — retrying from chunk $flushedChunkCount',
          );
        }
        await _delayBeforeRetry(attempt);
      }
    }
  }

  /// Pauses an active download by its ID.
  Future<void> pauseDownload(String downloadId) async {
    _cancelDioDownload(downloadId);
    final task = await _downloader.taskForId(downloadId);
    if (task != null && task is DownloadTask) {
      await _downloader.pause(task);
    }
    _activeDownloadIds.remove(downloadId);
  }

  /// Cancels an active download by its ID.
  Future<void> cancelDownload(String downloadId) async {
    _cancelDioDownload(downloadId);
    await _downloader.cancelTaskWithId(downloadId);
    _activeDownloadIds.remove(downloadId);
    _cleanSubscription(downloadId);
  }

  /// Checks if a download is currently active.
  bool isDownloadActive(String downloadId) {
    return _activeDownloadIds.contains(downloadId);
  }

  /// Gets the count of active downloads.
  int get activeDownloadsCount => _activeDownloadIds.length;

  /// Cancels all active downloads.
  Future<void> cancelAllDownloads() async {
    await _downloader.cancelAll();
    for (final token in _dioCancelTokens.values) {
      token.cancel('All downloads canceled');
    }
    _dioCancelTokens.clear();
    _activeDownloadIds.clear();
    for (final sub in _subscriptions.values) {
      await sub.cancel();
    }
    _subscriptions.clear();
  }

  /// Gets the file size from the URL headers using a HEAD request.
  Future<int?> getFileSize(String url, {Map<String, String>? headers}) async {
    try {
      final client = HttpClient();
      final request = await client.headUrl(Uri.parse(url));
      headers?.forEach((key, value) {
        request.headers.set(key, value);
      });
      final response = await request.close();
      final contentLength = response.contentLength;
      return contentLength > 0 ? contentLength : null;
    } catch (e) {
      return null;
    }
  }

  void _cleanSubscription(String downloadId) {
    final sub = _subscriptions.remove(downloadId);
    sub?.cancel();
  }

  void _cancelDioDownload(String downloadId) {
    final matchingIds = _dioCancelTokens.keys
        .where((id) => id == downloadId || id.startsWith('${downloadId}_'))
        .toList();
    for (final id in matchingIds) {
      _dioCancelTokens.remove(id)?.cancel('Download canceled');
      _activeDownloadIds.remove(id);
    }
  }

  String _formatFailureDetails(TaskStatusUpdate update) {
    final parts = <String>[
      'Download failed with status: ${update.status}',
      if (update.responseStatusCode != null)
        'HTTP ${update.responseStatusCode}',
      if (update.exception != null) update.exception.toString(),
      if (update.responseBody != null && update.responseBody!.isNotEmpty)
        update.responseBody!,
    ];
    return parts.join(' | ');
  }

  Future<void> _downloadWithDio({
    required Task task,
    required String originalUrl,
    required String savePath,
    required Map<String, String> headers,
    required CancelToken cancelToken,
    required ProgressCallback onProgress,
  }) async {
    final fallbackTask = await handleTokenRefresh(task);
    final fallbackUrl = fallbackTask?.url ?? task.url;
    var effectiveUrl = fallbackUrl.isEmpty ? originalUrl : fallbackUrl;

    // Needed for the mid-transfer link-refresh-and-retry below: the same
    // metaData handleTokenRefresh already reads to do its *pre-attempt*
    // refresh.
    String? sourceUrl;
    String? qualityLabel;
    var trackType = 'video';
    try {
      if (task is DownloadTask && task.metaData.isNotEmpty) {
        final data = jsonDecode(task.metaData) as Map<String, dynamic>;
        sourceUrl = data['sourceUrl'] as String?;
        qualityLabel = data['qualityLabel'] as String?;
        trackType = data['trackType'] as String? ?? 'video';
      }
    } catch (_) {
      // metaData is only used for the optional link-refresh path below;
      // a malformed value just means that path stays unavailable.
    }

    final targetFile = File(savePath);

    if (!await targetFile.parent.exists()) {
      await targetFile.parent.create(recursive: true);
    }
    if (await targetFile.exists()) {
      await targetFile.delete();
    }

    if (kDebugMode) {
      debugPrint('Download via Dio for task ${task.taskId}');
    }

    final dio = _dioFactory();

    Future<void> applyPinningIfNeeded(String forUrl) async {
      if (isSupabaseHost(forUrl, configuredSupabaseUrl: AppConstants.supabaseUrl)) {
        final certs = await _pinnedCertsLoader();
        if (certs.isNotEmpty) {
          applyCertificatePinning(dio, pinnedCertificatesPem: certs);
        }
      } else if (kDebugMode) {
        debugPrint(
          'ℹ️ [DownloadManager] URL domain (${Uri.tryParse(forUrl)?.host}) is an external CDN. '
          'Using standard TLS validation (Supabase pinning bypassed for external CDN).',
        );
      }
    }

    await applyPinningIfNeeded(effectiveUrl);
    final usedParallelDownload = await _tryDownloadWithParallelRanges(
      dio: dio,
      url: effectiveUrl,
      savePath: savePath,
      headers: headers,
      cancelToken: cancelToken,
      onProgress: onProgress,
    );
    if (usedParallelDownload) return;

    var attempt = 0;
    var linkRefreshUsed = false;
    while (true) {
      attempt++;
      try {
        await dio.download(
          effectiveUrl,
          savePath,
          options: Options(
            headers: headers,
            followRedirects: true,
            receiveTimeout: Duration.zero,
            sendTimeout: const Duration(seconds: 30),
            validateStatus: (status) =>
                status != null && status >= 200 && status < 300,
          ),
          cancelToken: cancelToken,
          onReceiveProgress: onProgress,
        );
        return;
      } catch (e) {
        if (cancelToken.isCancelled) rethrow;

        if (!linkRefreshUsed &&
            sourceUrl != null &&
            sourceUrl.isNotEmpty &&
            looksLikeExpiredLinkError(e)) {
          linkRefreshUsed = true;
          final fresh = await fetchFreshTrackUrl(
            sourceUrl: sourceUrl,
            qualityLabel: qualityLabel,
            trackType: trackType,
          );
          if (fresh != null && fresh.isNotEmpty && fresh != effectiveUrl) {
            if (kDebugMode) {
              debugPrint(
                '🔄 [DownloadManager] Link expired mid-download for task '
                '${task.taskId} — refreshed and retrying (not counted '
                'against the retry budget)',
              );
            }
            effectiveUrl = fresh;
            await applyPinningIfNeeded(effectiveUrl);
            attempt--; // link refresh isn't a "retry" of the same failure
            continue;
          }
        }

        if (attempt >= _maxWorkerAttempts || !isTransientDownloadError(e)) {
          rethrow;
        }
        if (kDebugMode) {
          debugPrint(
            'Whole-file dio.download failed (attempt $attempt): $e — '
            'retrying from scratch (no range support on this path)',
          );
        }
        await _delayBeforeRetry(attempt);
      }
    }
  }

  Future<bool> _tryDownloadWithParallelRanges({
    required Dio dio,
    required String url,
    required String savePath,
    required Map<String, String> headers,
    required CancelToken cancelToken,
    required ProgressCallback onProgress,
  }) async {
    try {
      final probe = await _probeRangeDownload(
        dio: dio,
        url: url,
        headers: headers,
        cancelToken: cancelToken,
      );
      if (probe == null || probe.totalBytes < _parallelDownloadMinBytes) {
        return false;
      }

      final chunkCount =
          probe.totalBytes >= _parallelDownloadLargeBytes ? 6 : 4;
      final ranges = _splitRanges(probe.totalBytes, chunkCount);
      final targetFile = File(savePath);
      final progressByRange = List<int>.filled(ranges.length, 0);

      final raf = await targetFile.open(mode: FileMode.write);
      try {
        await raf.truncate(probe.totalBytes);
      } finally {
        await raf.close();
      }

      if (kDebugMode) {
        debugPrint(
          'Parallel range download: ${ranges.length} parts, '
          '${probe.totalBytes} bytes',
        );
      }

      await Future.wait([
        for (var i = 0; i < ranges.length; i++)
          _downloadRange(
            dio: dio,
            url: url,
            savePath: savePath,
            headers: headers,
            range: ranges[i],
            rangeIndex: i,
            progressByRange: progressByRange,
            totalBytes: probe.totalBytes,
            cancelToken: cancelToken,
            onProgress: onProgress,
          ),
      ]);

      onProgress(probe.totalBytes, probe.totalBytes);
      return true;
    } catch (e) {
      if (cancelToken.isCancelled) rethrow;
      if (kDebugMode) {
        debugPrint('Parallel range download unavailable, falling back: $e');
      }
      return false;
    }
  }

  Future<_RangeProbe?> _probeRangeDownload({
    required Dio dio,
    required String url,
    required Map<String, String> headers,
    required CancelToken cancelToken,
  }) async {
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        final response = await dio.get<ResponseBody>(
          url,
          options: Options(
            headers: {
              ...headers,
              'Range': 'bytes=0-0',
            },
            followRedirects: true,
            responseType: ResponseType.stream,
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
            validateStatus: (status) => status == 206,
          ),
          cancelToken: cancelToken,
        );

        await _drainResponse(response.data);
        final contentRange = response.headers.value('content-range');
        final totalBytes = _parseTotalBytesFromContentRange(contentRange);
        if (totalBytes == null || totalBytes <= 0) return null;
        return _RangeProbe(totalBytes);
      } catch (e) {
        if (cancelToken.isCancelled) rethrow;
        if (attempt >= _maxWorkerAttempts || !isTransientDownloadError(e)) {
          rethrow;
        }
        if (kDebugMode) {
          debugPrint('Range probe failed (attempt $attempt): $e — retrying');
        }
        await _delayBeforeRetry(attempt);
      }
    }
  }

  Future<void> _downloadRange({
    required Dio dio,
    required String url,
    required String savePath,
    required Map<String, String> headers,
    required _ByteRange range,
    required int rangeIndex,
    required List<int> progressByRange,
    required int totalBytes,
    required CancelToken cancelToken,
    required ProgressCallback onProgress,
  }) async {
    // Resume point for retries: bytes already durably written to [savePath]
    // for this range are never re-fetched, so a stall/error partway through
    // only costs the retry backoff, not the bytes already on disk.
    var currentStart = range.start;
    var attempt = 0;

    while (true) {
      attempt++;
      try {
        final response = await dio.get<ResponseBody>(
          url,
          options: Options(
            headers: {
              ...headers,
              'Range': 'bytes=$currentStart-${range.end}',
            },
            followRedirects: true,
            responseType: ResponseType.stream,
            receiveTimeout: Duration.zero,
            sendTimeout: const Duration(seconds: 30),
            validateStatus: (status) => status == 206,
          ),
          cancelToken: cancelToken,
        );

        final body = response.data;
        if (body == null) {
          throw StateError('Range response body is empty');
        }

        final file = File(savePath);
        // FileMode.append (not .write): multiple range workers share this
        // same savePath concurrently, and FileMode.write truncates to zero
        // length on *every* open() call — a later worker (or, on retry,
        // this same worker) opening the file after a sibling has already
        // written data would silently wipe it out. .append never
        // truncates; setPosition() below still does a normal random-access
        // seek, so this doesn't force writes to the end of the file.
        final raf = await file.open(mode: FileMode.append);
        try {
          await raf.setPosition(currentStart);
          await for (final chunk in body.stream.timeout(_streamIdleTimeout)) {
            if (cancelToken.isCancelled) {
              throw cancelToken.cancelError ?? StateError('Download canceled');
            }
            await raf.writeFrom(chunk);
            currentStart += chunk.length;
            progressByRange[rangeIndex] += chunk.length;
            final received = progressByRange.fold<int>(
              0,
              (sum, item) => sum + item,
            );
            onProgress(received, totalBytes);
          }
        } finally {
          await raf.close();
        }
        return;
      } catch (e) {
        if (cancelToken.isCancelled) rethrow;
        if (attempt >= _maxWorkerAttempts || !isTransientDownloadError(e)) {
          rethrow;
        }
        if (kDebugMode) {
          debugPrint(
            'Range worker $rangeIndex stalled/failed (attempt $attempt): '
            '$e — retrying from byte $currentStart',
          );
        }
        await _delayBeforeRetry(attempt);
      }
    }
  }

  List<_ByteRange> _splitRanges(int totalBytes, int chunkCount) {
    final chunkSize = (totalBytes / chunkCount).ceil();
    return [
      for (var start = 0; start < totalBytes; start += chunkSize)
        _ByteRange(
          start,
          start + chunkSize - 1 > totalBytes - 1
              ? totalBytes - 1
              : start + chunkSize - 1,
        ),
    ];
  }

  int? _parseTotalBytesFromContentRange(String? contentRange) {
    if (contentRange == null) return null;
    final match = RegExp(r'bytes\s+\d+-\d+/(\d+)$').firstMatch(contentRange);
    return int.tryParse(match?.group(1) ?? '');
  }

  Future<void> _drainResponse(ResponseBody? body) async {
    if (body == null) return;
    await for (final _ in body.stream) {}
  }

  Future<void> _ensureFileAtSavePath(Task task, String savePath) async {
    try {
      final actualPath = await task.filePath();
      final downloadedFile = File(actualPath);
      final targetFile = File(savePath);

      if (downloadedFile.path != targetFile.path &&
          await downloadedFile.exists()) {
        if (!await targetFile.parent.exists()) {
          await targetFile.parent.create(recursive: true);
        }
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        try {
          await downloadedFile.rename(targetFile.path);
        } catch (_) {
          await downloadedFile.copy(targetFile.path);
          await downloadedFile.delete();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [_ensureFileAtSavePath] File move warning: $e');
      }
    }
  }

  /// Disposes the download manager and cleans up active subscriptions.
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    for (final token in _dioCancelTokens.values) {
      token.cancel('Download manager disposed');
    }
    _dioCancelTokens.clear();
    _activeDownloadIds.clear();
  }
}

class _RangeProbe {
  final int totalBytes;

  const _RangeProbe(this.totalBytes);
}

class _ByteRange {
  final int start;
  final int end;

  const _ByteRange(this.start, this.end);
}

/// Minimal async mutex: serializes calls to [run] in submission order by
/// chaining onto a tail future, so concurrent workers sharing a single
/// [RandomAccessFile] (see `startEncryptedDownload`) never interleave a
/// `setPosition` from one worker with a `writeFrom` from another.
class _AsyncFileWriteLock {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}
