// ignore_for_file: avoid_redundant_argument_values

import 'dart:io';

import 'package:app/core/error/failures.dart';
import 'package:app/core/services/encryption_service.dart';
import 'package:app/features/downloads/data/datasources/download_local_ds.dart';
import 'package:app/features/downloads/data/datasources/download_remote_ds.dart';
import 'package:app/features/downloads/data/models/video_info.dart';
import 'package:app/features/downloads/data/repositories/download_repository_impl.dart';
import 'package:app/features/downloads/data/services/download_manager.dart';
import 'package:app/features/downloads/data/services/download_manifest_service.dart';
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

class MockDownloadManifestService extends Mock
    implements DownloadManifestService {}

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

    test('cancelDownload cleans up video and audio tracks for dual-track downloads', () async {
      final existingDownload = {
        'id': 'download-dual',
        'lesson_id': 'lesson-dual',
        'course_id': 'course-1',
        'title': 'Dual track lesson',
        'local_path': '/tmp/video-path',
        'encrypted_path': '/tmp/video-path.enc',
        'audio_path': '/tmp/audio-path.enc',
        'video_url': 'https://example.com/video.mp4',
        'quality': VideoQuality.p720.label,
        'file_size': 0,
        'download_status': DownloadStatus.downloading.name,
        'progress': 0.5,
        'downloaded_at': DateTime.now().millisecondsSinceEpoch,
        'expires_at': DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
      };

      when(() => localDataSource.getDownloadById('download-dual'))
          .thenAnswer((_) async => existingDownload);
      when(() => localDataSource.updateDownloadStatus('download-dual', 'failed'))
          .thenAnswer((_) async {});
      when(() => localDataSource.deleteEncryptedFile('/tmp/video-path.enc'))
          .thenAnswer((_) async {});
      when(() => localDataSource.deleteEncryptedFile('/tmp/video-path.enc.tmp'))
          .thenAnswer((_) async {});
      when(() => localDataSource.deleteEncryptedFile('/tmp/audio-path.enc'))
          .thenAnswer((_) async {});
      when(() => localDataSource.deleteEncryptedFile('/tmp/audio-path.enc.tmp'))
          .thenAnswer((_) async {});
      when(() => localDataSource.deleteDownload('download-dual'))
          .thenAnswer((_) async {});
      when(() => encryptionService.deleteKey('download-dual'))
          .thenAnswer((_) async {});
      when(() => downloadManager.cancelDownload('download-dual'))
          .thenAnswer((_) async {});

      final result = await repository.cancelDownload('download-dual');

      expect(result.isRight(), isTrue);
      verify(() => localDataSource.deleteEncryptedFile('/tmp/video-path.enc')).called(1);
      verify(() => localDataSource.deleteEncryptedFile('/tmp/video-path.enc.tmp')).called(1);
      verify(() => localDataSource.deleteEncryptedFile('/tmp/audio-path.enc')).called(1);
      verify(() => localDataSource.deleteEncryptedFile('/tmp/audio-path.enc.tmp')).called(1);
    });

    // Regression test for cancelDownload's key-deletion-failure guard,
    // the same fix as deleteDownload's identically-shaped one above (see
    // CHANGELOG.md "[Unreleased]") applied to this, the fourth and last
    // remaining place in this codebase that deleted a download's DB row
    // regardless of whether its AES key deletion actually succeeded.
    test(
        'cancelDownload does NOT delete the DB row and returns a Failure '
        'when key deletion fails, instead of orphaning the key', () async {
      final existingDownload = {
        'id': 'download-cancel-key-fail',
        'lesson_id': 'lesson-1',
        'course_id': 'course-1',
        'title': 'Test lesson',
        'local_path': '/tmp/local-path',
        'encrypted_path': '/tmp/encrypted-path',
        'video_url': 'https://example.com/video.mp4',
        'quality': VideoQuality.p720.label,
        'file_size': 0,
        'download_status': DownloadStatus.downloading.name,
        'progress': 0.4,
        'downloaded_at': DateTime.now().millisecondsSinceEpoch,
        'expires_at': DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
        'checksum': null,
        'last_accessed_at': null,
      };

      when(() => localDataSource.getDownloadById('download-cancel-key-fail'))
          .thenAnswer((_) async => existingDownload);
      when(() => localDataSource.updateDownloadStatus(
            'download-cancel-key-fail',
            'failed',
          )).thenAnswer((_) async {});
      when(() => localDataSource.deleteEncryptedFile('/tmp/encrypted-path'))
          .thenAnswer((_) async {});
      when(() => localDataSource.deleteEncryptedFile('/tmp/encrypted-path.tmp'))
          .thenAnswer((_) async {});
      when(() => downloadManager.cancelDownload('download-cancel-key-fail'))
          .thenAnswer((_) async {});
      when(() => encryptionService.deleteKey('download-cancel-key-fail'))
          .thenThrow(Exception('secure storage unavailable')); // check-ignore

      final result = await repository.cancelDownload('download-cancel-key-fail');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<StorageFailure>()),
        (_) => fail('expected a Left(StorageFailure)'),
      );
      verifyNever(() => localDataSource.deleteDownload(any()));
      // The status-flip to 'failed' still happens -- it's a separate,
      // unrelated try/catch -- so the row is never left stuck showing
      // "downloading" even though the row itself wasn't removed.
      verify(() => localDataSource.updateDownloadStatus(
            'download-cancel-key-fail',
            'failed',
          )).called(1);
    });

    // Regression tests for deleteDownload's key-deletion-failure guard,
    // added alongside the fix (see CHANGELOG.md "[Unreleased]") that
    // brought this explicit, user-initiated delete path in line with the
    // same safety net CleanupScheduler.runCleanup and
    // OfflineAccountGuard.purgeDownloadsForOtherAccounts already applied:
    // never delete the DB row if key deletion failed, so the AES key
    // can't become permanently orphaned in secure storage.
    group('deleteDownload', () {
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
        'download_status': DownloadStatus.completed.name,
        'progress': 1.0,
        'downloaded_at': DateTime.now().millisecondsSinceEpoch,
        'expires_at': DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
        'checksum': null,
        'last_accessed_at': null,
      };

      setUp(() {
        when(() => localDataSource.getDownloadById('download-1'))
            .thenAnswer((_) async => existingDownload);
        when(() => localDataSource.deleteEncryptedFile('/tmp/encrypted-path'))
            .thenAnswer((_) async {});
        when(() => localDataSource.deleteEncryptedFile('/tmp/encrypted-path.tmp'))
            .thenAnswer((_) async {});
        when(() => localDataSource.deleteEncryptedFile('/tmp/encrypted-path.idx'))
            .thenAnswer((_) async {});
      });

      test('deletes files, key, and DB row when key deletion succeeds', () async {
        when(() => encryptionService.deleteKey('download-1'))
            .thenAnswer((_) async {});
        when(() => localDataSource.deleteDownload('download-1'))
            .thenAnswer((_) async {});

        final result = await repository.deleteDownload('download-1');

        expect(result.isRight(), isTrue);
        verify(() => encryptionService.deleteKey('download-1')).called(1);
        verify(() => localDataSource.deleteDownload('download-1')).called(1);
      });

      test(
          'does NOT delete the DB row and returns a Failure when key '
          'deletion fails, instead of orphaning the key', () async {
        when(() => encryptionService.deleteKey('download-1'))
            .thenThrow(Exception('secure storage unavailable')); // check-ignore

        final result = await repository.deleteDownload('download-1');

        expect(result.isLeft(), isTrue);
        result.fold(
          (failure) => expect(failure, isA<StorageFailure>()),
          (_) => fail('expected a Left(StorageFailure)'),
        );
        verifyNever(() => localDataSource.deleteDownload(any()));
      });
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
        'entitlement_id': 'ent-1',
        'server_status': 'ACTIVE',
        'server_expires_at': DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
      };

      when(() => localDataSource.getDownloadById('download-1'))
          .thenAnswer((_) async => existingDownload);
      when(() => remoteDataSource.revalidateOfflineEntitlement(
            entitlementId: any(named: 'entitlementId'),
          )).thenAnswer(
        (_) async => {
          'status': 'ACTIVE',
          'expires_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        },
      );
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
      // Key-loss cleanup (see the dedicated regression tests below for why
      // this must happen): resumeDownload routes it through the same
      // _cleanupDownloadFiles helper cancel/delete use, which calls
      // deleteEncryptedFile for the base path plus its `.tmp`/`.idx`
      // sidecars.
      when(() => localDataSource.deleteEncryptedFile(encryptedPath))
          .thenAnswer((_) async {});
      when(() => localDataSource.deleteEncryptedFile('$encryptedPath.tmp'))
          .thenAnswer((_) async {});
      when(() => localDataSource.deleteEncryptedFile('$encryptedPath.idx'))
          .thenAnswer((_) async {});
      when(() => downloadManager.startEncryptedDownload(
            url: any(named: 'url'),
            encryptedSavePath: any(named: 'encryptedSavePath'),
            encryptionKeyBase64: any(named: 'encryptionKeyBase64'),
            onProgress: any(named: 'onProgress'),
            downloadId: any(named: 'downloadId'),
            headers: any(named: 'headers'),
            sourceUrl: any(named: 'sourceUrl'),
            qualityLabel: any(named: 'qualityLabel'),
            trackType: any(named: 'trackType'),
            lessonId: any(named: 'lessonId'),
          )).thenAnswer((invocation) async {
        final savePath = invocation.namedArguments[#encryptedSavePath] as String;
        await File(savePath).writeAsBytes([1, 2, 3]);
        final onProgress = invocation.namedArguments[#onProgress] as ProgressCallback;
        onProgress(3, 6);
        return invocation.namedArguments[#downloadId] as String? ?? 'download-1';
      });

      final result = await repository.resumeDownload('download-1');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(result.isRight(), isTrue);
      verify(() => localDataSource.getDownloadById('download-1')).called(1);
      verify(() => downloadManager.startEncryptedDownload(
            url: any(named: 'url'),
            encryptedSavePath: any(named: 'encryptedSavePath'),
            encryptionKeyBase64: any(named: 'encryptionKeyBase64'),
            onProgress: any(named: 'onProgress'),
            downloadId: any(named: 'downloadId'),
            headers: any(named: 'headers'),
            sourceUrl: any(named: 'sourceUrl'),
            qualityLabel: any(named: 'qualityLabel'),
            trackType: any(named: 'trackType'),
            lessonId: any(named: 'lessonId'),
          )).called(1);
    });

    test(
      'resumeDownload discards stale on-disk bytes and manifest chunk '
      'state when the encryption key was lost, instead of resuming under '
      'a new key on top of chunks the manifest still marks verified from '
      'the old, now-unrecoverable key',
      () async {
        final tempDir =
            await Directory.systemTemp.createTemp('download_repo_keyloss_test');
        addTearDown(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final encryptedPath = '${tempDir.path}/lesson-1.enc';
        final audioPath = '${tempDir.path}/lesson-1_audio.enc';
        // A final (not `.tmp`) file already exists on disk, as it would
        // for the pipelined chunked path (DownloadManager
        // .startEncryptedDownload writes chunks directly into the final
        // path, never a `.tmp` file) after a partial run under a key that
        // has since been lost.
        await File(encryptedPath).writeAsBytes([9, 9, 9]);

        final manifestService = MockDownloadManifestService();
        final repositoryWithManifest = DownloadRepositoryImpl(
          remoteDataSource: remoteDataSource,
          localDataSource: localDataSource,
          downloadManager: downloadManager,
          encryptionService: encryptionService,
          manifestService: manifestService,
        );

        final existingDownload = {
          'id': 'download-1',
          'lesson_id': 'lesson-1',
          'course_id': 'course-1',
          'title': 'Test lesson',
          'local_path': encryptedPath,
          'encrypted_path': encryptedPath,
          'audio_path': audioPath,
          'video_url': 'https://example.com/video.mp4',
          'audio_url': 'https://example.com/audio.m4a',
          'quality': VideoQuality.p720.label,
          'file_size': 0,
          'download_status': DownloadStatus.paused.name,
          'progress': 40.0,
          'downloaded_at': DateTime.now().millisecondsSinceEpoch,
          'expires_at':
              DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
          'checksum': null,
          'last_accessed_at': null,
          'entitlement_id': 'ent-1',
          'server_status': 'ACTIVE',
          'server_expires_at':
              DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
        };

        when(() => localDataSource.getDownloadById('download-1'))
            .thenAnswer((_) async => existingDownload);
        when(() => remoteDataSource.revalidateOfflineEntitlement(
              entitlementId: any(named: 'entitlementId'),
            )).thenAnswer(
          (_) async => {
            'status': 'ACTIVE',
            'expires_at':
                DateTime.now().add(const Duration(days: 30)).toIso8601String(),
          },
        );
        when(() => localDataSource.updateDownloadStatus('download-1', 'downloading'))
            .thenAnswer((_) async {});
        when(() => localDataSource.updateDownloadStatus('download-1', 'failed'))
            .thenAnswer((_) async {});
        when(() => localDataSource.updateProgress('download-1', any()))
            .thenAnswer((_) async {});
        when(() => localDataSource.updateDownload('download-1', any()))
            .thenAnswer((_) async {});
        // The encryption key is gone -- this is the exact condition the
        // fix must react to.
        when(() => encryptionService.retrieveKey('download-1'))
            .thenAnswer((_) async => null);
        when(() => encryptionService.generateEncryptionKey())
            .thenReturn('fresh-key');
        when(() => encryptionService.storeKey('download-1', 'fresh-key'))
            .thenAnswer((_) async {});
        when(() => encryptionService.calculateChecksum(any()))
            .thenAnswer((_) async => 'checksum');
        when(() => localDataSource.deleteEncryptedFile(encryptedPath))
            .thenAnswer((_) async {});
        when(() => localDataSource.deleteEncryptedFile('$encryptedPath.tmp'))
            .thenAnswer((_) async {});
        when(() => localDataSource.deleteEncryptedFile('$encryptedPath.idx'))
            .thenAnswer((_) async {});
        when(() => localDataSource.deleteEncryptedFile(audioPath))
            .thenAnswer((_) async {});
        when(() => localDataSource.deleteEncryptedFile('$audioPath.tmp'))
            .thenAnswer((_) async {});
        when(() => localDataSource.deleteEncryptedFile('$audioPath.idx'))
            .thenAnswer((_) async {});
        when(() => manifestService.deleteForDownload('download-1'))
            .thenAnswer((_) async {});
        when(() => manifestService.markRunning('download-1'))
            .thenAnswer((_) async {});
        when(() => manifestService.markCompleted('download-1'))
            .thenAnswer((_) async {});
        when(() => downloadManager.startEncryptedDownload(
              url: any(named: 'url'),
              encryptedSavePath: any(named: 'encryptedSavePath'),
              encryptionKeyBase64: any(named: 'encryptionKeyBase64'),
              onProgress: any(named: 'onProgress'),
              downloadId: any(named: 'downloadId'),
              headers: any(named: 'headers'),
              sourceUrl: any(named: 'sourceUrl'),
              qualityLabel: any(named: 'qualityLabel'),
              trackType: any(named: 'trackType'),
              onPlanCreated: any(named: 'onPlanCreated'),
              onChunkCommitted: any(named: 'onChunkCommitted'),
              completedChunkIndexes: any(named: 'completedChunkIndexes'),
              lessonId: any(named: 'lessonId'),
            )).thenAnswer((invocation) async {
          final savePath =
              invocation.namedArguments[#encryptedSavePath] as String;
          await File(savePath).writeAsBytes([1, 2, 3]);
          final onProgress =
              invocation.namedArguments[#onProgress] as ProgressCallback;
          onProgress(3, 3);
          return invocation.namedArguments[#downloadId] as String? ??
              'download-1';
        });
        // getVerifiedChunkIndexes is consulted for both the video and
        // audio track ids by DownloadRepositoryImpl's manifest-aware
        // path; stub it directly rather than via the local data source,
        // since it's exercised through the mocked DownloadManifestService.
        when(() => manifestService.getVerifiedChunkIndexes(any()))
            .thenAnswer((_) async => <int>{});

        final result = await repositoryWithManifest.resumeDownload('download-1');
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(result.isRight(), isTrue);
        // The stale final file (and its sidecars, for both tracks) must be
        // discarded -- never reused under the freshly generated key.
        verify(() => localDataSource.deleteEncryptedFile(encryptedPath))
            .called(1);
        verify(() => localDataSource.deleteEncryptedFile('$encryptedPath.tmp'))
            .called(1);
        verify(() => localDataSource.deleteEncryptedFile('$encryptedPath.idx'))
            .called(1);
        verify(() => localDataSource.deleteEncryptedFile(audioPath)).called(1);
        verify(() => localDataSource.deleteEncryptedFile('$audioPath.tmp'))
            .called(1);
        verify(() => localDataSource.deleteEncryptedFile('$audioPath.idx'))
            .called(1);
        // The manifest's chunk/session rows for this downloadId must be
        // wiped so a fresh plan starts with zero "verified" chunks under
        // the new key -- this is the actual bug fix: without it, chunks
        // verified under the old key would otherwise be treated as done
        // and never re-fetched under the new one.
        verify(() => manifestService.deleteForDownload('download-1')).called(1);
      },
    );

    test(
      'resumeDownload does NOT wipe manifest state when the encryption '
      'key is still available (the ordinary, correct resume path)',
      () async {
        final tempDir = await Directory.systemTemp
            .createTemp('download_repo_keypresent_test');
        addTearDown(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });
        final encryptedPath = '${tempDir.path}/lesson-1.enc';

        final manifestService = MockDownloadManifestService();
        final repositoryWithManifest = DownloadRepositoryImpl(
          remoteDataSource: remoteDataSource,
          localDataSource: localDataSource,
          downloadManager: downloadManager,
          encryptionService: encryptionService,
          manifestService: manifestService,
        );

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
          'progress': 40.0,
          'downloaded_at': DateTime.now().millisecondsSinceEpoch,
          'expires_at':
              DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
          'checksum': null,
          'last_accessed_at': null,
          'entitlement_id': 'ent-1',
          'server_status': 'ACTIVE',
          'server_expires_at':
              DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
        };

        when(() => localDataSource.getDownloadById('download-1'))
            .thenAnswer((_) async => existingDownload);
        when(() => remoteDataSource.revalidateOfflineEntitlement(
              entitlementId: any(named: 'entitlementId'),
            )).thenAnswer(
          (_) async => {
            'status': 'ACTIVE',
            'expires_at':
                DateTime.now().add(const Duration(days: 30)).toIso8601String(),
          },
        );
        when(() => localDataSource.updateDownloadStatus('download-1', 'downloading'))
            .thenAnswer((_) async {});
        when(() => localDataSource.updateProgress('download-1', any()))
            .thenAnswer((_) async {});
        when(() => localDataSource.updateDownload('download-1', any()))
            .thenAnswer((_) async {});
        when(() => encryptionService.retrieveKey('download-1'))
            .thenAnswer((_) async => 'existing-key');
        when(() => encryptionService.storeKey('download-1', 'existing-key'))
            .thenAnswer((_) async {});
        when(() => encryptionService.calculateChecksum(any()))
            .thenAnswer((_) async => 'checksum');
        when(() => manifestService.markRunning('download-1'))
            .thenAnswer((_) async {});
        when(() => manifestService.markCompleted('download-1'))
            .thenAnswer((_) async {});
        when(() => manifestService.getVerifiedChunkIndexes(any()))
            .thenAnswer((_) async => <int>{});
        when(() => downloadManager.startEncryptedDownload(
              url: any(named: 'url'),
              encryptedSavePath: any(named: 'encryptedSavePath'),
              encryptionKeyBase64: any(named: 'encryptionKeyBase64'),
              onProgress: any(named: 'onProgress'),
              downloadId: any(named: 'downloadId'),
              headers: any(named: 'headers'),
              sourceUrl: any(named: 'sourceUrl'),
              qualityLabel: any(named: 'qualityLabel'),
              trackType: any(named: 'trackType'),
              onPlanCreated: any(named: 'onPlanCreated'),
              onChunkCommitted: any(named: 'onChunkCommitted'),
              completedChunkIndexes: any(named: 'completedChunkIndexes'),
              lessonId: any(named: 'lessonId'),
            )).thenAnswer((invocation) async {
          final savePath =
              invocation.namedArguments[#encryptedSavePath] as String?;
          if (savePath != null) {
            await File(savePath).writeAsBytes([1, 2, 3]);
          }
          final onProgress =
              invocation.namedArguments[#onProgress] as ProgressCallback;
          onProgress(3, 3);
          return invocation.namedArguments[#downloadId] as String? ??
              'download-1';
        });

        final result = await repositoryWithManifest.resumeDownload('download-1');
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(result.isRight(), isTrue);
        verify(() => encryptionService.storeKey('download-1', 'existing-key'))
            .called(1);
        verifyNever(() => encryptionService.generateEncryptionKey());
        verifyNever(() => manifestService.deleteForDownload(any()));
        verifyNever(() => localDataSource.deleteEncryptedFile(any()));
      },
    );

    test(
      'resumeDownload rejects a download that is already completed '
      '(illegal completed -> downloading transition)',
      () async {
        final existingDownload = {
          'id': 'download-1',
          'lesson_id': 'lesson-1',
          'course_id': 'course-1',
          'title': 'Test lesson',
          'local_path': '/tmp/encrypted-path',
          'encrypted_path': '/tmp/encrypted-path',
          'video_url': 'https://example.com/video.mp4',
          'quality': VideoQuality.p720.label,
          'file_size': 12345,
          'download_status': DownloadStatus.completed.name,
          'progress': 100.0,
          'downloaded_at': DateTime.now().millisecondsSinceEpoch,
          'expires_at':
              DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
          'checksum': 'checksum',
          'last_accessed_at': null,
          'entitlement_id': 'ent-1',
          'server_status': 'ACTIVE',
        };

        when(() => localDataSource.getDownloadById('download-1'))
            .thenAnswer((_) async => existingDownload);

        final result = await repository.resumeDownload('download-1');

        expect(result.isLeft(), isTrue);
        expect(
          result.getLeft().toNullable(),
          isA<InvalidDownloadStateFailure>(),
        );
        verifyNever(() => remoteDataSource.revalidateOfflineEntitlement(
              entitlementId: any(named: 'entitlementId'),
            ));
        verifyNever(() => downloadManager.startEncryptedDownload(
              url: any(named: 'url'),
              encryptedSavePath: any(named: 'encryptedSavePath'),
              encryptionKeyBase64: any(named: 'encryptionKeyBase64'),
              onProgress: any(named: 'onProgress'),
              downloadId: any(named: 'downloadId'),
              headers: any(named: 'headers'),
              sourceUrl: any(named: 'sourceUrl'),
              qualityLabel: any(named: 'qualityLabel'),
              trackType: any(named: 'trackType'),
              lessonId: any(named: 'lessonId'),
            ));
        verifyNever(
          () => localDataSource.updateDownloadStatus('download-1', 'downloading'),
        );
      },
    );

    test(
      'resumeDownload rejects a download that is already downloading '
      '(prevents a concurrent second execution)',
      () async {
        final existingDownload = {
          'id': 'download-1',
          'lesson_id': 'lesson-1',
          'course_id': 'course-1',
          'title': 'Test lesson',
          'local_path': '/tmp/encrypted-path',
          'encrypted_path': '/tmp/encrypted-path',
          'video_url': 'https://example.com/video.mp4',
          'quality': VideoQuality.p720.label,
          'file_size': 0,
          'download_status': DownloadStatus.downloading.name,
          'progress': 40.0,
          'downloaded_at': DateTime.now().millisecondsSinceEpoch,
          'expires_at':
              DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
          'checksum': null,
          'last_accessed_at': null,
          'entitlement_id': 'ent-1',
          'server_status': 'ACTIVE',
        };

        when(() => localDataSource.getDownloadById('download-1'))
            .thenAnswer((_) async => existingDownload);

        final result = await repository.resumeDownload('download-1');

        expect(result.isLeft(), isTrue);
        expect(
          result.getLeft().toNullable(),
          isA<InvalidDownloadStateFailure>(),
        );
        verifyNever(() => remoteDataSource.revalidateOfflineEntitlement(
              entitlementId: any(named: 'entitlementId'),
            ));
      },
    );

    test(
      'pauseDownload rejects a download that is already completed',
      () async {
        final existingDownload = {
          'id': 'download-1',
          'download_status': DownloadStatus.completed.name,
        };

        when(() => localDataSource.getDownloadById('download-1'))
            .thenAnswer((_) async => existingDownload);

        final result = await repository.pauseDownload('download-1');

        expect(result.isLeft(), isTrue);
        expect(
          result.getLeft().toNullable(),
          isA<InvalidDownloadStateFailure>(),
        );
        verifyNever(() => downloadManager.pauseDownload(any()));
        verifyNever(
          () => localDataSource.updateDownloadStatus('download-1', 'paused'),
        );
      },
    );

    test(
      'pauseDownload succeeds for a download that is actively downloading',
      () async {
        final existingDownload = {
          'id': 'download-1',
          'download_status': DownloadStatus.downloading.name,
        };

        when(() => localDataSource.getDownloadById('download-1'))
            .thenAnswer((_) async => existingDownload);
        when(() => downloadManager.pauseDownload('download-1'))
            .thenAnswer((_) async {});
        when(() => localDataSource.updateDownloadStatus('download-1', 'paused'))
            .thenAnswer((_) async {});

        final result = await repository.pauseDownload('download-1');

        expect(result.isRight(), isTrue);
        verify(() => downloadManager.pauseDownload('download-1')).called(1);
        verify(
          () => localDataSource.updateDownloadStatus('download-1', 'paused'),
        ).called(1);
      },
    );

    test(
      'pauseDownload is idempotent when the download is already paused',
      () async {
        final existingDownload = {
          'id': 'download-1',
          'download_status': DownloadStatus.paused.name,
        };

        when(() => localDataSource.getDownloadById('download-1'))
            .thenAnswer((_) async => existingDownload);

        final result = await repository.pauseDownload('download-1');

        expect(result.isRight(), isTrue);
        verifyNever(() => downloadManager.pauseDownload(any()));
      },
    );

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
      when(() => remoteDataSource.authorizeOfflineDownload(
            lessonId: any(named: 'lessonId'),
            courseId: any(named: 'courseId'),
            downloadId: any(named: 'downloadId'),
          )).thenAnswer(
        (_) async => {
          'status': 'ACTIVE',
          'entitlement_id': 'ent-1',
          'expires_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        },
      );
      when(() => remoteDataSource.validateCourseAccess(
            lessonId: 'lesson-1',
            courseId: 'course-1',
          )).thenAnswer(
        (_) async => CourseAccessResult(
          allowed: true,
          expiresAt: DateTime.now().add(const Duration(days: 30)),
        ),
      );
      when(() => remoteDataSource.getVideoInfo(
            'https://example.com/source',
            lessonId: any(named: 'lessonId'),
          )).thenAnswer((_) async => videoInfo);
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
      when(() => downloadManager.startEncryptedDownload(
            url: any(named: 'url'),
            encryptedSavePath: any(named: 'encryptedSavePath'),
            encryptionKeyBase64: any(named: 'encryptionKeyBase64'),
            onProgress: any(named: 'onProgress'),
            downloadId: any(named: 'downloadId'),
            headers: any(named: 'headers'),
            sourceUrl: any(named: 'sourceUrl'),
            qualityLabel: any(named: 'qualityLabel'),
            trackType: any(named: 'trackType'),
            lessonId: any(named: 'lessonId'),
          )).thenAnswer((invocation) async {
        final savePath = invocation.namedArguments[#encryptedSavePath] as String;
        await File(savePath).writeAsBytes([1, 2, 3]);
        final onProgress =
            invocation.namedArguments[#onProgress] as ProgressCallback;
        onProgress(3, 3);
        return invocation.namedArguments[#downloadId] as String? ?? 'download-1';
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
      verify(() => downloadManager.startEncryptedDownload(
            url: 'https://example.com/audio.m4a',
            encryptedSavePath: audioPath,
            encryptionKeyBase64: any(named: 'encryptionKeyBase64'),
            onProgress: any(named: 'onProgress'),
            downloadId: 'download-1_audio',
            headers: any(named: 'headers'),
            sourceUrl: any(named: 'sourceUrl'),
            qualityLabel: any(named: 'qualityLabel'),
            trackType: any(named: 'trackType'),
            lessonId: any(named: 'lessonId'),
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
