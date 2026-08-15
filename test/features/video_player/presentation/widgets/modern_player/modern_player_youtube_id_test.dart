import 'package:app/features/video_player/presentation/widgets/modern_player/modern_player_youtube_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractModernPlayerVideoId', () {
    test('returns null for null input', () {
      expect(extractModernPlayerVideoId(null), isNull);
    });

    test('returns null for empty input', () {
      expect(extractModernPlayerVideoId(''), isNull);
    });

    test('returns a bare 11-char id unchanged', () {
      expect(extractModernPlayerVideoId('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    });

    test('extracts the id from a watch?v= URL', () {
      expect(
        extractModernPlayerVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('extracts the id from a youtu.be short URL', () {
      expect(
        extractModernPlayerVideoId('https://youtu.be/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('extracts the id from an embed URL', () {
      expect(
        extractModernPlayerVideoId('https://www.youtube.com/embed/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('extracts the id from a shorts URL', () {
      expect(
        extractModernPlayerVideoId('https://www.youtube.com/shorts/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('extracts the id from a live URL', () {
      expect(
        extractModernPlayerVideoId('https://www.youtube.com/live/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('extracts the id from a youtube-nocookie embed URL', () {
      expect(
        extractModernPlayerVideoId(
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
      expect(extractModernPlayerVideoId(url), isNull);
    });

    test('returns null for a bare 11-char string with JS-breaking characters', () {
      // Same length as a real id, but not shaped like one (contains a
      // quote) -- must not be treated as safe just because the length
      // matches.
      expect(extractModernPlayerVideoId('a"</scrpt>1'), isNull);
    });

    test('returns null for a string that attempts JS string-literal breakout', () {
      const malicious = 'x"); alert(document.cookie); //';
      expect(extractModernPlayerVideoId(malicious), isNull);
    });

    test('returns null for a string with a single-quote breakout attempt', () {
      const malicious = "x'); alert(1); //";
      expect(extractModernPlayerVideoId(malicious), isNull);
    });

    test('rejects a video id containing whitespace', () {
      expect(extractModernPlayerVideoId('dQw4w9WgX Q'), isNull);
    });
  });
}
