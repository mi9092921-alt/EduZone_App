import 'package:app/features/downloads/data/models/video_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VideoInfo.fromJson - Size and Key Parsing Tests', () {
    test('parses size_bytes as integer directly', () {
      final json = {
        'title': 'Test Video',
        'default_download_quality': '720p',
        'formats': [
          {
            'quality': '720p',
            'video_url': 'http://foo.bar',
            'size_bytes': 1048576, // 1 MB
            'has_audio': true,
            'requires_merge': false,
          }
        ],
      };

      final info = VideoInfo.fromJson(json);
      expect(info.formats.first.sizeBytes, 1048576);
    });

    test('parses human-readable size strings (MB, GB, KB, B, etc.) with tilde', () {
      final json = {
        'title': 'Test Video',
        'default_download_quality': '1080p',
        'formats': [
          {
            'quality_label': '1080p',
            'url': 'http://foo.bar',
            'size': '~120.5 MB',
            'has_audio': false,
            'requires_merge': true,
          }
        ],
        'audio': {
          'itag': 140,
          'url': 'http://audio.bar',
          'audio_size': '222.3 MB',
          'ext': 'm4a',
        }
      };

      final info = VideoInfo.fromJson(json);
      
      // Video size: ~120.5 MB = 120.5 * 1024 * 1024 = 126352588 bytes
      expect(info.formats.first.sizeBytes, (120.5 * 1024 * 1024).toInt());
      expect(info.formats.first.quality, '1080p');
      expect(info.formats.first.videoUrl, 'http://foo.bar');

      // Audio size: 222.3 MB = 222.3 * 1024 * 1024 = 233098444 bytes
      expect(info.audio, isNotNull);
      expect(info.audio!.sizeBytes, (222.3 * 1024 * 1024).toInt());
    });

    test('parses pure numeric strings for size_bytes', () {
      final json = {
        'title': 'Test Video',
        'default_download_quality': '360p',
        'formats': [
          {
            'quality': '360p',
            'video_url': 'http://foo.bar',
            'size_bytes': '5000000',
            'has_audio': true,
            'requires_merge': false,
          }
        ],
      };

      final info = VideoInfo.fromJson(json);
      expect(info.formats.first.sizeBytes, 5000000);
    });

    test('returns null sizeBytes when size is missing or invalid', () {
      final json = {
        'title': 'Test Video',
        'default_download_quality': '360p',
        'formats': [
          {
            'quality': '360p',
            'video_url': 'http://foo.bar',
            'size': 'invalid_size',
            'has_audio': true,
            'requires_merge': false,
          }
        ],
      };

      final info = VideoInfo.fromJson(json);
      expect(info.formats.first.sizeBytes, isNull);
    });

    test('getSizeForQuality combines video and audio size when requiresMerge is true', () {
      final json = {
        'title': 'Test Video',
        'default_download_quality': '1080p',
        'formats': [
          {
            'quality_label': '1080p',
            'url': 'http://foo.bar',
            'size': '100 MB',
            'has_audio': false,
            'requires_merge': true,
          }
        ],
        'audio': {
          'itag': 140,
          'url': 'http://audio.bar',
          'audio_size': '50.5 MB',
          'ext': 'm4a',
        }
      };

      final info = VideoInfo.fromJson(json);
      final size = info.getSizeForQuality('1080p');
      
      // Expected combined size = 100 MB + 50.5 MB = 150.5 MB
      final expectedCombined = (150.5 * 1024 * 1024).toInt();
      expect(size, expectedCombined);
    });

    test(
      'getSizeForQuality combines per-format audio_size when no global audio exists',
      () {
      final json = {
        'title': 'Test Video',
        'default_download_quality': '720p',
        'formats': [
          {
            'quality': '720p',
            'video_url': 'http://video.bar',
            'audio_url': 'http://audio.bar',
            'size': '100 MB',
            'audio_size': '25 MB',
            'has_audio': false,
            'requires_merge': true,
          }
        ],
      };

      final info = VideoInfo.fromJson(json);
      final format = info.formats.first;

      expect(format.audioUrl, 'http://audio.bar');
      expect(format.audioSizeBytes, (25 * 1024 * 1024).toInt());
      expect(info.getSizeForQuality('720p'), (125 * 1024 * 1024).toInt());
      },
    );
  });
}
