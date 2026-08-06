import 'package:app/features/video_player/presentation/widgets/modern_player/modern_player_html.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildModernPlayerHtml', () {
    test('interpolates the video id into the YT.Player config', () {
      final html = buildModernPlayerHtml(
        videoId: 'dQw4w9WgXcQ',
        platform: 'android',
        playerVars: '{"autoplay": 1}',
      );

      expect(html, contains('videoId: "dQw4w9WgXcQ"'));
    });

    test('interpolates the platform into the script', () {
      final html = buildModernPlayerHtml(
        videoId: 'dQw4w9WgXcQ',
        platform: 'ios',
        playerVars: '{"autoplay": 1}',
      );

      expect(html, contains('var platform = "ios";'));
    });

    test('interpolates the playerVars object as-is (not re-encoded)', () {
      const playerVars = '{"autoplay": 1,"controls": 1,"rel": 0}';
      final html = buildModernPlayerHtml(
        videoId: 'dQw4w9WgXcQ',
        platform: 'android',
        playerVars: playerVars,
      );

      expect(html, contains('playerVars: $playerVars,'));
    });

    test('defaults host to the nocookie domain', () {
      final html = buildModernPlayerHtml(
        videoId: 'dQw4w9WgXcQ',
        platform: 'android',
        playerVars: '{}',
      );

      expect(html, contains('var host = "https://www.youtube-nocookie.com";'));
    });

    test('honors a custom host override', () {
      final html = buildModernPlayerHtml(
        videoId: 'dQw4w9WgXcQ',
        platform: 'android',
        playerVars: '{}',
        host: 'https://www.youtube.com',
      );

      expect(html, contains('var host = "https://www.youtube.com";'));
    });

    test('includes the Flutter <-> JS message bridge and cleanup loop', () {
      final html = buildModernPlayerHtml(
        videoId: 'dQw4w9WgXcQ',
        platform: 'android',
        playerVars: '{}',
      );

      expect(html, contains('onYTMessage'));
      expect(html, contains('cleanupInterval'));
      expect(html, contains('loadVideo'));
    });

    test('produces a well-formed HTML document', () {
      final html = buildModernPlayerHtml(
        videoId: 'dQw4w9WgXcQ',
        platform: 'android',
        playerVars: '{}',
      );

      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('<div id="ytPlayer">'));
      expect(html.trim(), endsWith('</html>'));
    });
  });
}
