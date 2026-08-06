import 'package:app/features/video_player/data/models/streaming_video_info.dart';
import 'package:app/features/video_player/presentation/widgets/player4/player4_format_selection.dart';
import 'package:flutter_test/flutter_test.dart';

StreamingFormat _format(String quality) => StreamingFormat(
  quality: quality,
  ext: 'mp4',
  hasAudio: true,
  requiresMerge: false,
  videoUrl: 'https://example.com/$quality.mp4',
);

void main() {
  group('findDefaultStreamingFormat', () {
    test('returns null for an empty format list', () {
      expect(findDefaultStreamingFormat([], '720p'), isNull);
    });

    test('prefers an exact (case-insensitive) quality match', () {
      final formats = [_format('480p'), _format('720P'), _format('1080p')];
      final result = findDefaultStreamingFormat(formats, '720p');
      expect(result?.quality, '720P');
    });

    test('falls back to matching resolution height when no exact label match', () {
      final formats = [_format('480p30'), _format('720p60'), _format('1080p30')];
      final result = findDefaultStreamingFormat(formats, '720p');
      expect(result?.quality, '720p60');
    });

    test('falls back to the closest resolution height when no exact height exists', () {
      final formats = [_format('360p'), _format('1080p')];
      // 720p isn't available — 1080p (diff 360) is closer than 360p (diff 360)...
      // use a case with an unambiguous closest match instead.
      final result = findDefaultStreamingFormat(formats, '480p');
      // |480-360| = 120, |480-1080| = 600 — 360p is closer.
      expect(result?.quality, '360p');
    });

    test('falls back to the first format when nothing matches at all', () {
      final formats = [_format('audio-only'), _format('also-unmatched')];
      final result = findDefaultStreamingFormat(formats, '720p');
      expect(result?.quality, 'audio-only');
    });
  });
}
