import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:dio/dio.dart'
    show CancelToken, Dio, Options, ProgressCallback, ResponseBody, ResponseType;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/certificate_pinning.dart';
import '../../../../core/network/supabase_client.dart';


import '../../data/datasources/download_remote_ds.dart';
import '../../domain/entities/download_enums.dart';

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

    final freshUrl = trackType == 'audio'
        ? (selectedFormat?.audioUrl ?? freshInfo.audio?.url ?? task.url)
        : (selectedFormat?.videoUrl ??
            (freshInfo.formats.isNotEmpty
                ? freshInfo.formats.first.videoUrl
                : task.url));

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
  final Map<String, StreamSubscription<TaskUpdate>> _subscriptions = {};
  final Map<String, CancelToken> _dioCancelTokens = {};
  final Set<String> _activeDownloadIds = {};
  static const int _maxConcurrentDownloads = 3;
  static const int _parallelDownloadMinBytes = 8 * 1024 * 1024;
  static const int _parallelDownloadLargeBytes = 80 * 1024 * 1024;

  /// [dioFactory], [isAndroid], and [configureOnInit] exist purely as
  /// testing seams — production code should never pass them.
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
  })  : _downloader = downloader ?? FileDownloader(),
        _dioFactory = dioFactory ?? (() => Dio()),
        _isAndroid = isAndroid ?? Platform.isAndroid {
    if (configureOnInit) _configureDownloader();
  }

  void _configureDownloader() {
    _downloader.configureNotification(
      running: const TaskNotification(
        'EduZone download',
        'Downloading {filename}: {progress}',
      ),
      complete: const TaskNotification(
        'EduZone download',
        'Download complete',
      ),
      error: const TaskNotification(
        'EduZone download',
        'Download failed',
      ),
      paused: const TaskNotification(
        'EduZone download',
        'Download paused',
      ),
      canceled: const TaskNotification(
        'EduZone download',
        'Download canceled',
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
      throw Exception('Maximum concurrent downloads limit reached');
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

    if (_isAndroid) {
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
                Exception('Download canceled with status: ${update.status}'),
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
                      Exception('$failureDetails | Dio retry failed: $e'),
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
      throw Exception('Failed to enqueue download task: $effectiveDownloadId');
    }

    return completer.future;
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
    final effectiveUrl = fallbackUrl.isEmpty ? originalUrl : fallbackUrl;
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
    if (isSupabaseHost(effectiveUrl, configuredSupabaseUrl: AppConstants.supabaseUrl)) {
      final certs = await loadPinnedCertificatesAsset();
      if (certs.isNotEmpty) {
        applyCertificatePinning(dio, pinnedCertificatesPem: certs);
      }
    } else if (kDebugMode) {
      debugPrint(
        'ℹ️ [DownloadManager] URL domain (${Uri.tryParse(effectiveUrl)?.host}) is an external CDN. '
        'Using standard TLS validation (Supabase pinning bypassed for external CDN).',
      );
    }
    final usedParallelDownload = await _tryDownloadWithParallelRanges(

      dio: dio,
      url: effectiveUrl,
      savePath: savePath,
      headers: headers,
      cancelToken: cancelToken,
      onProgress: onProgress,
    );
    if (usedParallelDownload) return;

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
    final response = await dio.get<ResponseBody>(
      url,
      options: Options(
        headers: {
          ...headers,
          'Range': 'bytes=${range.start}-${range.end}',
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
    final raf = await file.open(mode: FileMode.write);
    try {
      await raf.setPosition(range.start);
      await for (final chunk in body.stream) {
        if (cancelToken.isCancelled) {
          throw cancelToken.cancelError ?? StateError('Download canceled');
        }
        await raf.writeFrom(chunk);
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