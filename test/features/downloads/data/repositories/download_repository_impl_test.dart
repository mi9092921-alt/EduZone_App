// ignore_for_file: avoid_redundant_argument_values

import 'dart:io';

import 'package:app/core/services/encryption_service.dart';
import 'package:app/features/downloads/data/datasources/download_local_ds.dart';
import 'package:app/features/downloads/data/datasources/download_remote_ds.dart';
import 'package:app/features/downloads/data/models/video_info.dart';
import 'package:app/features/downloads/data/repositories/download_repository_impl.dart';
import 'package:app/features/downloads/data/services/download_manager.dart';
import 'package:app/features/downloads/domain/entities/download_enums.dart';
import 'package:app/features/downloads/domain/entities/downloaded_lesson.dart';
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
    registerFallbackValue(DownloadedLesson.skeleton());
  });

  late DownloadRepositoryImpl repository;
  late MockDownloadRemoteDataSource remoteDataSource;
  late MockDownloadLocalDataSource localDataSource;
  late MockDownloadManager downloadManager;
  late MockEncryptionService encryptionService;

  setUp(() {
    remoteDataSource = MockDownloadRemoteDataSource();
    localDataSource = MockDownloadLocalDataSource();
    downloadManager = MockDownloadManager();
    encryptionService = MockEncryptionService();
    repository = DownloadRepositoryImpl(
      remoteDataSource: remoteDataSource,
      localDataSource: localDataSource,
      downloadManager: downloadManager,
      encryptionService: encryptionService,
    );
  });

  group('DownloadRepositoryImpl', () {
    test('cancelDownload uses the download id to remove the saved record', () async {
      final existingDownload = {
        'id': 'download-1',
        'lesson_id': 'lesson-1',
        'course_id': 'course-1',
        'title': 'Test lesson',
        'local_path': '/tmp/local-path',
        'encrypted_path': '/tmp/encrypted-path',
        'video_url': 'https://example.com/video.mp4',
        'quality': VideoQuality.p720.label,
        'file_size': 0,
        'download_status': DownloadStatus.pending.name,
        'progress': 0.0,
        'downloaded_at': DateTime.now().millisecondsSinceEpoch,
        'expires_at': DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
        'checksum': null,
        'last_accessed_at': null,
      };

      when(() => localDataSource.getDownloadById('download-1'))
          .thenAnswer((_) async => existingDownload);
      when(() => localDataSource.updateDownloadStatus('download-1', 'failed'))
          .thenAnswer((_) async {});
      when(() => localDataSource.deleteEncryptedFile('/tmp/encrypted-path'))
          .thenAnswer((_) async {});
      when(() => localDataSource.deleteEncryptedFile('/tmp/encrypted-path.tmp'))
          .thenAnswer((_) async {});
      when(() => localDataSource.deleteDownload('download-1'))
          .thenAnswer((_) async {});
      when(() => encryptionService.deleteKey('download-1'))
          .thenAnswer((_) async {});
      when(() => downloadManager.cancelDownload('download-1'))
          .thenAnswer((_) async {});

      final result = await repository.cancelDownload('download-1');

      expect(result.isRight(), isTrue);
      verify(() => localDataSource.getDownloadById('download-1')).called(1);
      verify(() => localDataSource.deleteDownload('download-1')).called(1);
      verify(() => encryptionService.deleteKey('download-1')).called(1);
    });

    test('resumeDownload restarts a stored download from its saved URL', () async {
      final tempDir = await Directory.systemTemp.createTemp('download_repo_test');
      addTearDown(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final encryptedPath = '${tempDir.path}/lesson-1.enc';
      final tempPath = '$encryptedPath.tmp';
      await File(tempPath).writeAsBytes([1, 2, 3]);

      final existingDownload = {
        'id': 'download-1',
        'lesson_id': 'lesson-1',
        'course_id': 'course-1',
        'title': 'Test lesson',
        'local_path': encryptedPath,
        'encrypted_path': encryptedPath,
        'video_url': 'https://example.com/video.mp4',
        'quality': VideoQuality.p720.label,
        'file_size': 0,
        'download_status': DownloadStatus.paused.name,
        'progress': 25.0,
        'downloaded_at': DateTime.now().millisecondsSinceEpoch,
        'expires_at': DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
        'checksum': null,
        'last_accessed_at': null,
      };

      when(() => localDataSource.getDownloadById('download-1'))
          .thenAnswer((_) async => existingDownload);
      when(() => localDataSource.updateDownloadStatus('download-1', 'downloading'))
          .thenAnswer((_) async {});
      when(() => localDataSource.updateDownloadStatus('download-1', 'failed'))
          .thenAnswer((_) async {});
      when(() => localDataSource.updateProgress('download-1', any()))
          .thenAnswer((_) async {});
      when(() => localDataSource.updateDownload('download-1', any()))
          .thenAnswer((_) async {});
      when(() => encryptionService.retrieveKey('download-1'))
          .thenAnswer((_) async => null);
      when(() => encryptionService.generateEncryptionKey()).thenReturn('test-key');
      when(() => encryptionService.storeKey('download-1', 'test-key'))
          .thenAnswer((_) async {});
      when(() => encryptionService.encryptFile(any(), any(), 'test-key'))
          .thenAnswer((invocation) async {
            final destination = invocation.positionalArguments[1] as File;
            await destination.writeAsBytes([4, 5, 6]);
          });
      when(() => encryptionService.calculateChecksum(any()))
          .thenAnswer((_) async => 'checksum');
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
        await File(savePath).writeAsBytes([1, 2, 3]);
        final onProgress = invocation.namedArguments[#onProgress] as ProgressCallback;
        onProgress(3, 6);
        return 'download-1';
      });

      final result = await repository.resumeDownload('download-1');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(result.isRight(), isTrue);
      verify(() => localDataSource.getDownloadById('download-1')).called(1);
      verify(() => downloadManager.startDownload(
            downloadId: any(named: 'downloadId'),
            url: any(named: 'url'),
            savePath: any(named: 'savePath'),
            onProgress: any(named: 'onProgress'),
            headers: any(named: 'headers'),
            sourceUrl: any(named: 'sourceUrl'),
            qualityLabel: any(named: 'qualityLabel'),
            trackType: any(named: 'trackType'),
          )).called(1);
    });

    test('startDownload uses per-format audio_url for dual-track downloads', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'download_repo_audio_test',
      );
      addTearDown(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final videoPath = '${tempDir.path}/lesson-1_720p.mp4.enc';
      final audioPath = '${tempDir.path}/lesson-1_720p_audio.m4a.enc';

      final videoInfo = VideoInfo.fromJson({
        'title': 'Test Video',
        'default_download_quality': '720p',
        'formats': [
          {
            'quality': '720p',
            'video_url': 'https://example.com/video.mp4',
            'audio_url': 'https://example.com/audio.m4a',
            'size': '10 MB',
            'audio_size': '2 MB',
            'has_audio': false,
            'requires_merge': true,
          }
        ],
      });

      when(() => localDataSource.getDownloadByLessonId('lesson-1'))
          .thenAnswer((_) async => null);
      when(() => remoteDataSource.validateCourseAccess(
            lessonId: 'lesson-1',
            courseId: 'course-1',
          )).thenAnswer(
        (_) async => CourseAccessResult(
          allowed: true,
          expiresAt: DateTime.now().add(const Duration(days: 30)),
        ),
      );
      when(() => remoteDataSource.getVideoInfo('https://example.com/source'))
          .thenAnswer((_) async => videoInfo);
      when(() => localDataSource.getTotalStorageUsed())
          .thenAnswer((_) async => 0);
      when(() => localDataSource.generateDownloadId()).thenReturn('download-1');
      when(() => localDataSource.createFilePath(
            lessonId: 'lesson-1',
            quality: VideoQuality.p720.label,
            ext: 'mp4',
          )).thenAnswer((_) async => videoPath);
      when(() => localDataSource.createAudioFilePath(
            lessonId: 'lesson-1',
            quality: VideoQuality.p720.label,
            ext: 'm4a',
          )).thenAnswer((_) async => audioPath);
      when(() => encryptionService.generateEncryptionKey()).thenReturn('test-key');
      when(() => encryptionService.storeKey('download-1', 'test-key'))
          .thenAnswer((_) async {});
      when(() => localDataSource.insertDownload(any())).thenAnswer((_) async {});
      when(() => localDataSource.updateDownloadStatus(any(), any()))
          .thenAnswer((_) async {});
      when(() => localDataSource.updateProgress(any(), any()))
          .thenAnswer((_) async {});
      when(() => localDataSource.updateDownload(any(), any()))
          .thenAnswer((_) async {});
      when(() => encryptionService.encryptFile(any(), any(), 'test-key'))
          .thenAnswer((invocation) async {
        final destination = invocation.positionalArguments[1] as File;
        await destination.writeAsBytes([4, 5, 6]);
      });
      when(() => encryptionService.calculateChecksum(any()))
          .thenAnswer((_) async => 'checksum');
      when(() => remoteDataSource.logDownloadAttempt(
            lessonId: any(named: 'lessonId'),
            quality: any(named: 'quality'),
            accessExpiresAt: any(named: 'accessExpiresAt'),
          )).thenAnswer((_) async {});
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
        await File(savePath).writeAsBytes([1, 2, 3]);
        final onProgress =
            invocation.namedArguments[#onProgress] as ProgressCallback;
        onProgress(3, 3);
        return invocation.namedArguments[#downloadId] as String;
      });

      final result = await repository.startDownload(
        lessonId: 'lesson-1',
        courseId: 'course-1',
        courseTitle: 'Course',
        title: 'Lesson',
        videoUrl: 'https://example.com/source',
        quality: VideoQuality.p720,
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(result.isRight(), isTrue);
      final captured =
          verify(() => localDataSource.insertDownload(captureAny())).captured;
      final download = captured.single as DownloadedLesson;
      expect(download.audioPath, audioPath);
      expect(download.audioUrl, 'https://example.com/audio.m4a');
      verify(() => localDataSource.createAudioFilePath(
            lessonId: 'lesson-1',
            quality: VideoQuality.p720.label,
            ext: 'm4a',
          )).called(1);
      verify(() => downloadManager.startDownload(
            downloadId: 'download-1_audio',
            url: 'https://example.com/audio.m4a',
            savePath: '$audioPath.tmp',
            onProgress: any(named: 'onProgress'),
            headers: any(named: 'headers'),
            sourceUrl: any(named: 'sourceUrl'),
            qualityLabel: any(named: 'qualityLabel'),
            trackType: 'audio',
          )).called(1);
    });

    test('getDownloads correctly maps database rows to entities', () async {
      final dbRow = {
        'id': 'download-1',
        'lesson_id': 'lesson-1',
        'course_id': 'course-1',
        'title': 'Test lesson',
        'local_path': '/tmp/local-path',
        'encrypted_path': '/tmp/encrypted-path',
        'video_url': 'https://example.com/video.mp4',
        'quality': '720p',
        'file_size': 54525952,
        'download_status': 'completed',
        'progress': 100.0,
        'downloaded_at': 1719572400000,
        'expires_at': 1722164400000,
        'checksum': null,
        'last_accessed_at': null,
      };

      when(() => localDataSource.getDownloads()).thenAnswer((_) async => [dbRow]);

      final result = await repository.getDownloads();

      expect(result.isRight(), isTrue);
      final downloads = result.getOrElse((_) => []);
      expect(downloads.length, equals(1));
      final item = downloads.first;
      expect(item.id, equals('download-1'));
      expect(item.quality, equals(VideoQuality.p720));
      expect(item.status, equals(DownloadStatus.completed));
      expect(item.fileSize, equals(54525952));
    });
  });
}
