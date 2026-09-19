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
      // SECURITY (AUTH/WEBVIEW-01): this used to pass the raw string
      // through unchanged, which flowed straight into an unescaped JS
      // string literal inside the WebView. Anything that isn't a real
      // YouTube id must resolve to null so the caller shows the
      // "invalid video URL" state instead of building a WebView.
      const url = 'https://example.com/video/123';
      expect(extractYoutubeVideoId(url), isNull);
    });

    test('returns null for a bare 11-char string with JS-breaking characters', () {
      // Same length as a real id, but not shaped like one (contains a
      // quote) -- must not be treated as safe just because the length
      // matches.
      expect(extractYoutubeVideoId('a"</scrpt>1'), isNull);
    });

    test('returns null for a string that attempts JS string-literal breakout', () {
      const malicious = 'x"); alert(document.cookie); //';
      expect(extractYoutubeVideoId(malicious), isNull);
    });

    test('returns null for a string with a single-quote breakout attempt', () {
      const malicious = "x'); alert(1); //";
      expect(extractYoutubeVideoId(malicious), isNull);
    });

    test('rejects a video id containing whitespace', () {
      expect(extractYoutubeVideoId('dQw4w9WgX Q'), isNull);
    });
  });
}
