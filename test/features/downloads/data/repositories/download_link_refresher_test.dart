import 'package:app/features/downloads/data/datasources/download_local_ds.dart';
import 'package:app/features/downloads/data/datasources/download_remote_ds.dart';
import 'package:app/features/downloads/data/models/video_info.dart';
import 'package:app/features/downloads/data/repositories/download_link_refresher.dart';
import 'package:app/features/downloads/domain/entities/download_enums.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDownloadRemoteDataSource extends Mock
    implements DownloadRemoteDataSource {}

class MockDownloadLocalDataSource extends Mock
    implements DownloadLocalDataSource {}

void main() {
  late DownloadLinkRefresher refresher;
  late MockDownloadRemoteDataSource remoteDataSource;
  late MockDownloadLocalDataSource localDataSource;

  setUp(() {
    remoteDataSource = MockDownloadRemoteDataSource();
    localDataSource = MockDownloadLocalDataSource();
    refresher = DownloadLinkRefresher(
      remoteDataSource: remoteDataSource,
      localDataSource: localDataSource,
    );
  });

  group('DownloadLinkRefresher', () {
    test('does nothing when the link is not stale yet', () async {
      final result = await refresher.refreshIfStale(
        downloadId: 'download-1',
        currentVideoUrl: 'https://example.com/current.mp4',
        currentAudioUrl: null,
        sourceUrl: 'https://example.com/source',
        linkValidatedAt: DateTime.now().subtract(const Duration(hours: 1)),
        quality: VideoQuality.p720,
      );

      expect(result.refreshed, isFalse);
      expect(result.videoUrl, 'https://example.com/current.mp4');
      verifyNever(() => remoteDataSource.getVideoInfo(any()));
      verifyNever(() => localDataSource.updateDownload(any(), any()));
    });

    test('does nothing when stale but there is no source URL to refresh from',
        () async {
      final result = await refresher.refreshIfStale(
        downloadId: 'download-1',
        currentVideoUrl: 'https://example.com/current.mp4',
        currentAudioUrl: null,
        sourceUrl: null,
        linkValidatedAt: DateTime.now().subtract(const Duration(hours: 6)),
        quality: VideoQuality.p720,
      );

      expect(result.refreshed, isFalse);
      verifyNever(() => remoteDataSource.getVideoInfo(any()));
    });

    test('treats a never-validated link (null timestamp) as stale', () async {
      final videoInfo = VideoInfo.fromJson({
        'title': 'Test Video',
        'default_download_quality': '720p',
        'formats': [
          {
            'quality': '720p',
            'video_url': 'https://example.com/fresh.mp4',
            'has_audio': true,
            'requires_merge': false,
          },
        ],
      });

      when(() => remoteDataSource.getVideoInfo('https://example.com/source'))
          .thenAnswer((_) async => videoInfo);
      when(() => localDataSource.updateDownload('download-1', any()))
          .thenAnswer((_) async {});

      final result = await refresher.refreshIfStale(
        downloadId: 'download-1',
        currentVideoUrl: 'https://example.com/current.mp4',
        currentAudioUrl: null,
        sourceUrl: 'https://example.com/source',
        linkValidatedAt: null,
        quality: VideoQuality.p720,
      );

      expect(result.refreshed, isTrue);
      expect(result.videoUrl, 'https://example.com/fresh.mp4');
    });

    test(
      'fetches, persists, and returns a fresh link when the stored link is '
      'older than the staleness threshold',
      () async {
        final videoInfo = VideoInfo.fromJson({
          'title': 'Test Video',
          'default_download_quality': '720p',
          'formats': [
            {
              'quality': '720p',
              'video_url': 'https://example.com/refreshed_video.mp4',
              'audio_url': 'https://example.com/refreshed_audio.m4a',
              'has_audio': false,
              'requires_merge': true,
            },
          ],
        });

        when(() =>
                remoteDataSource.getVideoInfo('https://example.com/source'))
            .thenAnswer((_) async => videoInfo);
        when(() => localDataSource.updateDownload('download-1', any()))
            .thenAnswer((_) async {});

        final result = await refresher.refreshIfStale(
          downloadId: 'download-1',
          currentVideoUrl: 'https://example.com/stale.mp4',
          currentAudioUrl: null,
          sourceUrl: 'https://example.com/source',
          linkValidatedAt:
              DateTime.now().subtract(const Duration(hours: 6)),
          quality: VideoQuality.p720,
        );

        expect(result.refreshed, isTrue);
        expect(result.videoUrl, 'https://example.com/refreshed_video.mp4');
        expect(result.audioUrl, 'https://example.com/refreshed_audio.m4a');

        final captured = verify(
          () => localDataSource.updateDownload('download-1', captureAny()),
        ).captured;
        final updates = captured.single as Map<String, dynamic>;
        expect(updates['video_url'], 'https://example.com/refreshed_video.mp4');
        expect(
          updates['audio_url'],
          'https://example.com/refreshed_audio.m4a',
        );
        expect(updates['link_validated_at'], isA<int>());
      },
    );

    test('falls back to the stored URL when the refresh call throws',
        () async {
      when(() => remoteDataSource.getVideoInfo('https://example.com/source'))
          .thenThrow(Exception('network error'));

      final result = await refresher.refreshIfStale(
        downloadId: 'download-1',
        currentVideoUrl: 'https://example.com/stale.mp4',
        currentAudioUrl: 'https://example.com/stale_audio.m4a',
        sourceUrl: 'https://example.com/source',
        linkValidatedAt: DateTime.now().subtract(const Duration(hours: 6)),
        quality: VideoQuality.p720,
      );

      expect(result.refreshed, isFalse);
      expect(result.videoUrl, 'https://example.com/stale.mp4');
      expect(result.audioUrl, 'https://example.com/stale_audio.m4a');
      verifyNever(() => localDataSource.updateDownload(any(), any()));
    });
  });
}
