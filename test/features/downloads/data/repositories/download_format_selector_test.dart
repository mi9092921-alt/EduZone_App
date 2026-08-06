import 'package:app/features/downloads/data/models/video_info.dart';
import 'package:app/features/downloads/data/repositories/download_format_selector.dart';
import 'package:app/features/downloads/domain/entities/download_enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DownloadFormatSelector', () {
    const selector = DownloadFormatSelector();

    test('prefers an exact-quality muxed format over everything else', () {
      final videoInfo = VideoInfo.fromJson({
        'title': 'Test Video',
        'default_download_quality': '720p',
        'formats': [
          {
            'quality': '720p',
            'video_url': 'https://example.com/muxed720.mp4',
            'has_audio': true,
            'requires_merge': false,
          },
          {
            'quality': '720p',
            'video_url': 'https://example.com/video720.mp4',
            'audio_url': 'https://example.com/audio720.m4a',
            'has_audio': false,
            'requires_merge': true,
          },
        ],
      });

      final result = selector.select(videoInfo, VideoQuality.p720);

      expect(result.isDualTrack, isFalse);
      expect(result.videoFormat.videoUrl, 'https://example.com/muxed720.mp4');
    });

    test('falls back to exact-quality video-only + per-format audio_url', () {
      final videoInfo = VideoInfo.fromJson({
        'title': 'Test Video',
        'default_download_quality': '720p',
        'formats': [
          {
            'quality': '720p',
            'video_url': 'https://example.com/video720.mp4',
            'audio_url': 'https://example.com/audio720.m4a',
            'size': '10 MB',
            'audio_size': '2 MB',
            'has_audio': false,
            'requires_merge': true,
          },
        ],
      });

      final result = selector.select(videoInfo, VideoQuality.p720);

      expect(result.isDualTrack, isTrue);
      expect(result.videoFormat.videoUrl, 'https://example.com/video720.mp4');
      expect(result.audioTrack!.url, 'https://example.com/audio720.m4a');
    });

    test(
      'falls back to the shared video_info.audio track when a format has '
      'no per-format audio_url',
      () {
        final videoInfo = VideoInfo.fromJson({
          'title': 'Test Video',
          'default_download_quality': '720p',
          'formats': [
            {
              'quality': '720p',
              'video_url': 'https://example.com/video720.mp4',
              'has_audio': false,
              'requires_merge': true,
            },
          ],
          'audio': {
            'url': 'https://example.com/shared_audio.m4a',
            'ext': 'm4a',
          },
        });

        final result = selector.select(videoInfo, VideoQuality.p720);

        expect(result.isDualTrack, isTrue);
        expect(result.audioTrack!.url, 'https://example.com/shared_audio.m4a');
      },
    );

    test('picks the closest available quality when the exact one is absent',
        () {
      final videoInfo = VideoInfo.fromJson({
        'title': 'Test Video',
        'default_download_quality': '480p',
        'formats': [
          {
            'quality': '360p',
            'video_url': 'https://example.com/360.mp4',
            'has_audio': true,
            'requires_merge': false,
          },
          {
            'quality': '1080p',
            'video_url': 'https://example.com/1080.mp4',
            'has_audio': true,
            'requires_merge': false,
          },
        ],
      });

      // Requested 720p: 360p is 2 steps away, 1080p is 1 step away.
      final result = selector.select(videoInfo, VideoQuality.p720);

      expect(result.videoFormat.videoUrl, 'https://example.com/1080.mp4');
    });

    test('prefers a muxed format over a merge-required one at equal distance',
        () {
      final videoInfo = VideoInfo.fromJson({
        'title': 'Test Video',
        'default_download_quality': '480p',
        'formats': [
          {
            // Same quality distance from p720 as the option below, but
            // requires a merge — should lose to the muxed one.
            'quality': '480p',
            'video_url': 'https://example.com/480_merge.mp4',
            'has_audio': false,
            'requires_merge': true,
          },
          {
            'quality': '1080p',
            'video_url': 'https://example.com/1080_muxed.mp4',
            'has_audio': true,
            'requires_merge': false,
          },
        ],
      });

      final result = selector.select(videoInfo, VideoQuality.p720);

      expect(result.videoFormat.videoUrl, 'https://example.com/1080_muxed.mp4');
      expect(result.isDualTrack, isFalse);
    });

    test('throws when there are no usable formats at all', () {
      final videoInfo = VideoInfo.fromJson({
        'title': 'Test Video',
        'default_download_quality': '720p',
        'formats': <Map<String, dynamic>>[],
      });

      expect(
        () => selector.select(videoInfo, VideoQuality.p720),
        throwsA(isA<Exception>()),
      );
    });
  });
}
