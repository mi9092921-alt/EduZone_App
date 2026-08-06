// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';
import 'dart:io';

import 'package:app/core/services/encryption_service.dart';
import 'package:app/features/downloads/data/datasources/download_local_ds.dart';
import 'package:app/features/downloads/data/datasources/download_remote_ds.dart';
import 'package:app/features/downloads/data/repositories/download_execution_service.dart';
import 'package:app/features/downloads/data/services/download_manager.dart';
import 'package:app/features/downloads/domain/entities/download_enums.dart';
import 'package:app/features/downloads/domain/entities/download_progress.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDownloadRemoteDataSource extends Mock
    implements DownloadRemoteDataSource {}

class MockDownloadLocalDataSource extends Mock
    implements DownloadLocalDataSource {}

class MockDownloadManager extends Mock implements DownloadManager {}

class MockEncryptionService extends Mock implements EncryptionService {}

void main() {
  setUpAll(() {
    registerFallbackValue(File('dummy'));
  });

  late MockDownloadRemoteDataSource remoteDataSource;
  late MockDownloadLocalDataSource localDataSource;
  late MockDownloadManager downloadManager;
  late MockEncryptionService encryptionService;

  // The same shared session-state instances DownloadRepositoryImpl would
  // own and pass in by reference — see ARCH-006.
  late Map<String, StreamController<DownloadProgress>> progressControllers;
  late Map<String, String> downloadManagerIds;
  late Set<String> pausedDownloads;
  late Set<String> cancelledDownloads;
  late StreamController<void> changeController;

  late DownloadExecutionService service;
  late Directory tempDir;

  setUp(() async {
    remoteDataSource = MockDownloadRemoteDataSource();
    localDataSource = MockDownloadLocalDataSource();
    downloadManager = MockDownloadManager();
    encryptionService = MockEncryptionService();

    progressControllers = {};
    downloadManagerIds = {};
    pausedDownloads = {};
    cancelledDownloads = {};
    changeController = StreamController<void>.broadcast();

    service = DownloadExecutionService(
      remoteDataSource: remoteDataSource,
      localDataSource: localDataSource,
      downloadManager: downloadManager,
      encryptionService: encryptionService,
      progressControllers: progressControllers,
      downloadManagerIds: downloadManagerIds,
      pausedDownloads: pausedDownloads,
      cancelledDownloads: cancelledDownloads,
      changeController: changeController,
    );

    tempDir = await Directory.systemTemp.createTemp('download_exec_test');

    when(() => localDataSource.updateDownloadStatus(any(), any()))
        .thenAnswer((_) async {});
    when(() => localDataSource.updateProgress(any(), any()))
        .thenAnswer((_) async {});
    when(() => localDataSource.updateDownload(any(), any()))
        .thenAnswer((_) async {});
    when(() => encryptionService.calculateChecksum(any()))
        .thenAnswer((_) async => 'checksum');
    when(() => remoteDataSource.logDownloadAttempt(
          lessonId: any(named: 'lessonId'),
          quality: any(named: 'quality'),
          accessExpiresAt: any(named: 'accessExpiresAt'),
        )).thenAnswer((_) async {});
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    for (final c in progressControllers.values) {
      if (!c.isClosed) await c.close();
    }
    await changeController.close();
  });

  group('DownloadExecutionService.execute — single file', () {
    test('downloads via the pipelined path and persists completion', () async {
      final videoSavePath = '${tempDir.path}/lesson.mp4.enc';

      when(() => downloadManager.startEncryptedDownload(
            downloadId: any(named: 'downloadId'),
            url: any(named: 'url'),
            encryptedSavePath: any(named: 'encryptedSavePath'),
            encryptionKeyBase64: any(named: 'encryptionKeyBase64'),
            onProgress: any(named: 'onProgress'),
          )).thenAnswer((invocation) async {
        final savePath =
            invocation.namedArguments[#encryptedSavePath] as String;
        await File(savePath).writeAsBytes(List.filled(10, 1));
        final onProgress =
            invocation.namedArguments[#onProgress] as ProgressCallback;
        onProgress(10, 10);
        return 'manager-1';
      });

      await service.execute(
        downloadId: 'd1',
        title: 'Lesson 1',
        videoUrl: 'https://example.com/video.mp4',
        videoSavePath: videoSavePath,
        encryptionKey: 'test-key',
        lessonId: 'lesson-1',
        quality: VideoQuality.p720,
        accessExpiresAt: null,
        sourceUrl: 'https://example.com/source',
      );

      final captured = verify(
        () => localDataSource.updateDownload('d1', captureAny()),
      ).captured;
      final finalUpdate =
          captured.last as Map<String, dynamic>;
      expect(finalUpdate['download_status'], 'completed');
      expect(finalUpdate['progress'], 100.0);
      expect(finalUpdate['file_size'], 10);
      expect(finalUpdate['checksum'], 'checksum');

      verify(() => localDataSource.updateDownloadStatus('d1', 'downloading'))
          .called(1);
      verify(() => remoteDataSource.logDownloadAttempt(
            lessonId: 'lesson-1',
            quality: VideoQuality.p720.label,
            accessExpiresAt: null,
          )).called(1);

      // Cleaned up after completion.
      expect(progressControllers.containsKey('d1'), isFalse);
    });

    test('falls back to download-then-encrypt when the pipelined path '
        'declines', () async {
      final videoSavePath = '${tempDir.path}/lesson.mp4.enc';

      when(() => downloadManager.startEncryptedDownload(
            downloadId: any(named: 'downloadId'),
            url: any(named: 'url'),
            encryptedSavePath: any(named: 'encryptedSavePath'),
            encryptionKeyBase64: any(named: 'encryptionKeyBase64'),
            onProgress: any(named: 'onProgress'),
          )).thenAnswer((_) async => null);

      when(() => downloadManager.startDownload(
            downloadId: any(named: 'downloadId'),
            url: any(named: 'url'),
            savePath: any(named: 'savePath'),
            onProgress: any(named: 'onProgress'),
            headers: any(named: 'headers'),
            sourceUrl: any(named: 'sourceUrl'),
            qualityLabel: any(named: 'qualityLabel'),
            trackType: any(named: 'trackType'),
          )).thenAnswer((invocation) async {
        final savePath = invocation.namedArguments[#savePath] as String;
        await File(savePath).writeAsBytes(List.filled(5, 2));
        final onProgress =
            invocation.namedArguments[#onProgress] as ProgressCallback;
        onProgress(5, 5);
        return 'manager-legacy';
      });

      when(() => encryptionService.encryptFile(any(), any(), 'test-key'))
          .thenAnswer((invocation) async {
        final destination = invocation.positionalArguments[1] as File;
        await destination.writeAsBytes(List.filled(5, 2));
      });

      await service.execute(
        downloadId: 'd2',
        title: 'Lesson 2',
        videoUrl: 'https://example.com/video.mp4',
        videoSavePath: videoSavePath,
        encryptionKey: 'test-key',
        lessonId: 'lesson-2',
        quality: VideoQuality.p720,
        sourceUrl: 'https://example.com/source',
      );

      verify(() => encryptionService.encryptFile(any(), any(), 'test-key'))
          .called(1);
      final captured = verify(
        () => localDataSource.updateDownload('d2', captureAny()),
      ).captured;
      expect((captured.last as Map<String, dynamic>)['download_status'],
          'completed');
    });
  });

  group('DownloadExecutionService.execute — dual track', () {
    test('downloads video and audio in parallel and sums file sizes',
        () async {
      final videoSavePath = '${tempDir.path}/lesson.mp4.enc';
      final audioSavePath = '${tempDir.path}/lesson_audio.m4a.enc';

      when(() => downloadManager.startEncryptedDownload(
            downloadId: any(named: 'downloadId'),
            url: any(named: 'url'),
            encryptedSavePath: any(named: 'encryptedSavePath'),
            encryptionKeyBase64: any(named: 'encryptionKeyBase64'),
            onProgress: any(named: 'onProgress'),
          )).thenAnswer((invocation) async {
        final savePath =
            invocation.namedArguments[#encryptedSavePath] as String;
        final isAudio = savePath.contains('audio');
        await File(savePath).writeAsBytes(List.filled(isAudio ? 4 : 8, 3));
        final onProgress =
            invocation.namedArguments[#onProgress] as ProgressCallback;
        onProgress(isAudio ? 4 : 8, isAudio ? 4 : 8);
        return isAudio ? 'manager-audio' : 'manager-video';
      });

      await service.execute(
        downloadId: 'd3',
        title: 'Lesson 3',
        videoUrl: 'https://example.com/video.mp4',
        videoSavePath: videoSavePath,
        audioUrl: 'https://example.com/audio.m4a',
        audioSavePath: audioSavePath,
        encryptionKey: 'test-key',
        lessonId: 'lesson-3',
        quality: VideoQuality.p720,
        sourceUrl: 'https://example.com/source',
      );

      final captured = verify(
        () => localDataSource.updateDownload('d3', captureAny()),
      ).captured;
      final finalUpdate = captured.last as Map<String, dynamic>;
      expect(finalUpdate['download_status'], 'completed');
      expect(finalUpdate['file_size'], 12); // 8 (video) + 4 (audio)
    });
  });

  group('DownloadExecutionService.execute — failure and pause handling', () {
    test('marks the download failed when the underlying download throws',
        () async {
      when(() => downloadManager.startEncryptedDownload(
            downloadId: any(named: 'downloadId'),
            url: any(named: 'url'),
            encryptedSavePath: any(named: 'encryptedSavePath'),
            encryptionKeyBase64: any(named: 'encryptionKeyBase64'),
            onProgress: any(named: 'onProgress'),
          )).thenThrow(Exception('network down'));
      when(() => downloadManager.startDownload(
            downloadId: any(named: 'downloadId'),
            url: any(named: 'url'),
            savePath: any(named: 'savePath'),
            onProgress: any(named: 'onProgress'),
            headers: any(named: 'headers'),
            sourceUrl: any(named: 'sourceUrl'),
            qualityLabel: any(named: 'qualityLabel'),
            trackType: any(named: 'trackType'),
          )).thenThrow(Exception('network down'));

      await service.execute(
        downloadId: 'd4',
        title: 'Lesson 4',
        videoUrl: 'https://example.com/video.mp4',
        videoSavePath: '${tempDir.path}/lesson4.mp4.enc',
        encryptionKey: 'test-key',
        lessonId: 'lesson-4',
        quality: VideoQuality.p720,
        sourceUrl: 'https://example.com/source',
      );

      verify(() => localDataSource.updateDownloadStatus('d4', 'failed'))
          .called(1);
      verifyNever(() => localDataSource.updateDownload('d4', any()));
      expect(progressControllers.containsKey('d4'), isFalse);
    });

    test('marks the download paused (without deleting temp files) when the '
        'download id was pre-marked as paused', () async {
      when(() => downloadManager.startEncryptedDownload(
            downloadId: any(named: 'downloadId'),
            url: any(named: 'url'),
            encryptedSavePath: any(named: 'encryptedSavePath'),
            encryptionKeyBase64: any(named: 'encryptionKeyBase64'),
            onProgress: any(named: 'onProgress'),
          )).thenAnswer((_) async {
        // Simulate the manager cancelling mid-flight because pauseDownload()
        // was called concurrently, which surfaces as a thrown error here.
        throw Exception('paused by user');
      });
      when(() => downloadManager.startDownload(
            downloadId: any(named: 'downloadId'),
            url: any(named: 'url'),
            savePath: any(named: 'savePath'),
            onProgress: any(named: 'onProgress'),
            headers: any(named: 'headers'),
            sourceUrl: any(named: 'sourceUrl'),
            qualityLabel: any(named: 'qualityLabel'),
            trackType: any(named: 'trackType'),
          )).thenThrow(Exception('paused by user'));

      // This is exactly what DownloadRepositoryImpl.pauseDownload() does
      // before the execution throws.
      pausedDownloads.add('d5');

      await service.execute(
        downloadId: 'd5',
        title: 'Lesson 5',
        videoUrl: 'https://example.com/video.mp4',
        videoSavePath: '${tempDir.path}/lesson5.mp4.enc',
        encryptionKey: 'test-key',
        lessonId: 'lesson-5',
        quality: VideoQuality.p720,
        sourceUrl: 'https://example.com/source',
      );

      verify(() => localDataSource.updateDownloadStatus('d5', 'paused'))
          .called(1);
      verifyNever(() => localDataSource.updateDownloadStatus('d5', 'failed'));
      // The paused id is consumed (removed) once handled.
      expect(pausedDownloads.contains('d5'), isFalse);
    });

    test('does nothing extra when the download id was already cancelled',
        () async {
      when(() => downloadManager.startEncryptedDownload(
            downloadId: any(named: 'downloadId'),
            url: any(named: 'url'),
            encryptedSavePath: any(named: 'encryptedSavePath'),
            encryptionKeyBase64: any(named: 'encryptionKeyBase64'),
            onProgress: any(named: 'onProgress'),
          )).thenThrow(Exception('cancelled'));
      when(() => downloadManager.startDownload(
            downloadId: any(named: 'downloadId'),
            url: any(named: 'url'),
            savePath: any(named: 'savePath'),
            onProgress: any(named: 'onProgress'),
            headers: any(named: 'headers'),
            sourceUrl: any(named: 'sourceUrl'),
            qualityLabel: any(named: 'qualityLabel'),
            trackType: any(named: 'trackType'),
          )).thenThrow(Exception('cancelled'));

      cancelledDownloads.add('d6');

      await service.execute(
        downloadId: 'd6',
        title: 'Lesson 6',
        videoUrl: 'https://example.com/video.mp4',
        videoSavePath: '${tempDir.path}/lesson6.mp4.enc',
        encryptionKey: 'test-key',
        lessonId: 'lesson-6',
        quality: VideoQuality.p720,
        sourceUrl: 'https://example.com/source',
      );

      verifyNever(() => localDataSource.updateDownloadStatus('d6', 'failed'));
      verifyNever(() => localDataSource.updateDownloadStatus('d6', 'paused'));
      expect(cancelledDownloads.contains('d6'), isFalse);
    });
  });

  group('DownloadExecutionService.closeProgressController', () {
    test('closes and removes the controller and manager id', () async {
      // ignore: close_sinks
      final controller = StreamController<DownloadProgress>.broadcast();
      progressControllers['d7'] = controller;
      downloadManagerIds['d7'] = 'manager-7';

      await service.closeProgressController('d7');

      expect(controller.isClosed, isTrue);
      expect(progressControllers.containsKey('d7'), isFalse);
      expect(downloadManagerIds.containsKey('d7'), isFalse);
    });

    test('is a no-op when called for an id with no controller', () async {
      await service.closeProgressController('missing-id');
      // Should not throw.
    });

    test('is safe to call twice for the same id', () async {
      final controller = StreamController<DownloadProgress>.broadcast();
      progressControllers['d8'] = controller;

      await service.closeProgressController('d8');
      await service.closeProgressController('d8', controller);
      // Should not throw even though the controller is already closed.
    });
  });
}
