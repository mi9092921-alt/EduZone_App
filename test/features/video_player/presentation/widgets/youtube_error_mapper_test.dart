import 'package:app/features/video_player/presentation/widgets/youtube_error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

import 'player4/player4_test_helpers.dart';

void main() {
  group('mapYoutubeErrorCodeToMessage', () {
    testWidgets('maps malformed video ids to the invalid-URL message', (
      WidgetTester tester,
    ) async {
      await withLocalizations(tester, (l10n) {
        // IFrame codes 1 (invalid request parameter) and 2 (malformed id).
        expect(mapYoutubeErrorCodeToMessage(l10n, 1), l10n.invalidVideoUrl);
        expect(mapYoutubeErrorCodeToMessage(l10n, 2), l10n.invalidVideoUrl);
      });
    });

    testWidgets(
      'maps removed/private/embedding-disabled videos to the access-denied '
      'message',
      (WidgetTester tester) async {
        await withLocalizations(tester, (l10n) {
          // 100: removed/private; 101/150: owner disabled embedding.
          expect(
            mapYoutubeErrorCodeToMessage(l10n, 100),
            l10n.videoAccessDenied,
          );
          expect(
            mapYoutubeErrorCodeToMessage(l10n, 101),
            l10n.videoAccessDenied,
          );
          expect(
            mapYoutubeErrorCodeToMessage(l10n, 150),
            l10n.videoAccessDenied,
          );
        });
      },
    );

    testWidgets('falls back to the code-bearing generic message', (
      WidgetTester tester,
    ) async {
      await withLocalizations(tester, (l10n) {
        // 5: HTML5 playback fault; -1: package fallback for a malformed
        // JS payload; 999: unknown future code. None have dedicated copy,
        // so each must keep its code visible for support triage.
        expect(
          mapYoutubeErrorCodeToMessage(l10n, 5),
          l10n.videoLoadErrorCode(5),
        );
        expect(
          mapYoutubeErrorCodeToMessage(l10n, -1),
          l10n.videoLoadErrorCode(-1),
        );
        expect(
          mapYoutubeErrorCodeToMessage(l10n, 999),
          l10n.videoLoadErrorCode(999),
        );
      });
    });
  });
}
