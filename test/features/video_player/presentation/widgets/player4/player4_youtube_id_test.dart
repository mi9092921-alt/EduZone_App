import 'package:app/shared/utils/youtube_video_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractYoutubeVideoId', () {
    test('returns null for null input', () {
      expect(extractYoutubeVideoId(null), isNull);
    });

    test('returns null for empty input', () {
      expect(extractYoutubeVideoId(''), isNull);
    });

    test('returns a bare 11-char id unchanged', () {
      expect(extractYoutubeVideoId('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    });

    test('extracts the id from a watch?v= URL', () {
      expect(
        extractYoutubeVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('extracts the id from a youtu.be short URL', () {
      expect(
        extractYoutubeVideoId('https://youtu.be/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('extracts the id from an embed URL', () {
      expect(
        extractYoutubeVideoId('https://www.youtube.com/embed/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('extracts the id from a shorts URL', () {
      expect(
        extractYoutubeVideoId('https://www.youtube.com/shorts/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('extracts the id from a live URL', () {
      expect(
        extractYoutubeVideoId('https://www.youtube.com/live/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('extracts the id from a youtube-nocookie embed URL', () {
      expect(
        extractYoutubeVideoId(
          'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ',
        ),
        'dQw4w9WgXcQ',
      );
    });

    test('returns null for an unrecognized URL shape', () {
      // Hardened semantics (shared with the modern player): the old
      // player4 copy passed unrecognized input through unchanged, which
      // let non-YouTube strings flow into the player. Anything that
      // isn't a real YouTube id must resolve to null so the caller
      // shows the "invalid video URL" state.
      const url = 'https://example.com/video/123';
      expect(extractYoutubeVideoId(url), isNull);
    });
  });
}
