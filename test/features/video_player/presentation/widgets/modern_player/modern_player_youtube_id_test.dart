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

    test('passes through an unrecognized URL shape unchanged', () {
      const url = 'https://example.com/video/123';
      expect(extractModernPlayerVideoId(url), url);
    });
  });
}
